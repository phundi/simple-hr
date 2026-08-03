class OnboardingController < ApplicationController
  before_action :set_user
  before_action :set_employee

  def show
  end

  def update
    @employee.assign_attributes(employee_params)
    @user.assign_attributes(filtered_user_params)

    if @employee.valid? && @user.valid?
      ActiveRecord::Base.transaction do
        @employee.onboarding_status = :verified
        @employee.save!

        @user.onboarding_status = :verified
        @user.save!
      end

      redirect_to onboarding_path(token: params[:token]), notice: "Your details were verified and updated successfully."
    else
      flash.now[:alert] = "Please fix the highlighted fields and try again."
      render :show, status: :unprocessable_entity
    end
  end

  private

  def set_user
    @user = User.find_by!(verification_token: params[:token])
  rescue ActiveRecord::RecordNotFound
    render plain: "Invalid or expired onboarding link.", status: :not_found
  end

  def set_employee
    @employee = @user.employee || @user.company.employees.find_or_initialize_by(user: @user)
    @employee.company ||= @user.company
    @employee.onboarding_status ||= :unverified
    @employee.employment_status ||= :active
    @employee.payment_method ||= :cash
    @employee.account_holder_name ||= [ @user.first_name, @user.last_name ].compact.join(" ").strip.presence
  end

  def user_params
    params.require(:user).permit(:first_name, :last_name, :phone_number, :two_factor_enabled, :two_factor_method)
  end

  def filtered_user_params
    attrs = user_params.to_h

    unless @user.company&.pro?
      attrs["two_factor_enabled"] = false
      attrs["two_factor_method"] = nil
      return attrs
    end

    attrs["two_factor_enabled"] = ActiveModel::Type::Boolean.new.cast(attrs["two_factor_enabled"])
    attrs["two_factor_method"] = nil unless attrs["two_factor_enabled"]
    attrs
  end

  def employee_params
    params.require(:employee).permit(
      :payment_method,
      :bank_name,
      :bank_branch,
      :bank_account_number,
      :account_type,
      :account_holder_name,
      :swift_code,
      :mobile_money_number,
      :mobile_money_provider
    )
  end
end
