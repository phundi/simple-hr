class UsersController < ApplicationController
  before_action :set_user, only: [ :show, :edit, :update, :destroy, :block, :unblock, :resend_invite ]
  before_action :ensure_authenticated_user!, only: [ :account, :update_account ]

  def index
    @users = current_company.users.order(created_at: :desc)
  end

  def show
  end

  def new
    @user = current_company.users.new(role: :hr, status: :invited, onboarding_status: :unverified)
  end

  def create
    generated_password = SecureRandom.base58(12)
    @user = current_company.users.new(user_params.merge(
      password: generated_password,
      password_confirmation: generated_password,
      onboarding_status: :unverified
    ))

    if @user.save
      @user.send_verification!
      redirect_to users_path, notice: "User created successfully. Verification invite sent."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @user.update(user_params)
      redirect_to users_path, notice: "User updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @user.destroy!
    redirect_to users_path, notice: "User deleted successfully."
  rescue ActiveRecord::RecordNotDestroyed => e
    redirect_to users_path, alert: "Could not delete user: #{e.record.errors.full_messages.to_sentence}"
  end

  def block
    @user.block!(reason: params[:reason])
    redirect_back fallback_location: root_path, notice: "User blocked successfully."
  rescue ActiveRecord::RecordInvalid => e
    redirect_back fallback_location: root_path, alert: "Could not block user: #{e.record.errors.full_messages.to_sentence}"
  end

  def unblock
    @user.unblock!
    redirect_back fallback_location: root_path, notice: "User unblocked successfully."
  rescue ActiveRecord::RecordInvalid => e
    redirect_back fallback_location: root_path, alert: "Could not unblock user: #{e.record.errors.full_messages.to_sentence}"
  end

  def resend_invite
    @user.update!(status: :invited, onboarding_status: :unverified)
    @user.send_verification!
    redirect_back fallback_location: users_path, notice: "Invite resent successfully."
  rescue ActiveRecord::RecordInvalid => e
    redirect_back fallback_location: users_path, alert: "Could not resend invite: #{e.record.errors.full_messages.to_sentence}"
  end

  def account
    @account_user = current_user
    @preferences = {
      email_notifications: @account_user.preference("email_notifications", fallback: "true"),
      whatsapp_notifications: @account_user.preference("whatsapp_notifications", fallback: "false"),
      language: @account_user.preference("language", fallback: "en")
    }
    @enable_2fa = ActiveModel::Type::Boolean.new.cast(ConfigService.get(nil, current_company, "enable_2fa") || "false")
  end

  def update_account
    @account_user = current_user
    tab = params[:tab].presence_in(%w[profile security preferences]) || "profile"

    case tab
    when "profile"
      if @account_user.update(profile_params)
        redirect_to account_users_path(tab: "profile"), notice: "Profile updated."
      else
        @preferences = current_preferences_for(@account_user)
        @enable_2fa = ActiveModel::Type::Boolean.new.cast(ConfigService.get(nil, current_company, "enable_2fa") || "false")
        render :account, status: :unprocessable_entity
      end
    when "security"
      unless ActiveModel::Type::Boolean.new.cast(ConfigService.get(nil, current_company, "enable_2fa") || "false")
        security_attrs = security_params.to_h
        security_attrs["two_factor_enabled"] = false
        security_attrs["two_factor_method"] = nil
      else
        security_attrs = security_params.to_h
      end

      if @account_user.update(security_attrs)
        redirect_to account_users_path(tab: "security"), notice: "Security settings updated."
      else
        @preferences = current_preferences_for(@account_user)
        @enable_2fa = ActiveModel::Type::Boolean.new.cast(ConfigService.get(nil, current_company, "enable_2fa") || "false")
        render :account, status: :unprocessable_entity
      end
    else
      save_preference(@account_user, "email_notifications", preference_params[:email_notifications])
      save_preference(@account_user, "whatsapp_notifications", preference_params[:whatsapp_notifications])
      save_preference(@account_user, "language", preference_params[:language])

      redirect_to account_users_path(tab: "preferences"), notice: "Preferences updated."
    end
  end

  private

  def ensure_authenticated_user!
    redirect_to new_user_session_path, alert: "Please sign in." unless current_user
  end

  def set_user
    @user = current_company.users.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:first_name, :last_name, :email, :phone_number, :role, :status)
  end

  def profile_params
    params.require(:user).permit(:avatar, :first_name, :last_name, :phone_number)
  end

  def security_params
    params.require(:user).permit(:password, :password_confirmation, :two_factor_enabled, :two_factor_method)
  end

  def preference_params
    params.require(:preferences).permit(:email_notifications, :whatsapp_notifications, :language)
  end

  def save_preference(user, key, value)
    cfg = user.user_configs.find_or_initialize_by(key: key)
    cfg.data_type = key == "language" ? "string" : "boolean"
    cfg.value = key == "language" ? value.to_s : (ActiveModel::Type::Boolean.new.cast(value) ? "true" : "false")
    cfg.save!
  end

  def current_preferences_for(user)
    {
      email_notifications: user.preference("email_notifications", fallback: "true"),
      whatsapp_notifications: user.preference("whatsapp_notifications", fallback: "false"),
      language: user.preference("language", fallback: "en")
    }
  end
end
