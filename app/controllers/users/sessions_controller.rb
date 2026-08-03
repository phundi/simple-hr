class Users::SessionsController < Devise::SessionsController
  skip_before_action :authenticate_user!, only: [ :new, :create, :demo_sign_in ]
  layout "public"

  def demo_sign_in
    role = params[:role].to_s
    email = case role
    when "hr"
      "hr@demo.com"
    when "admin"
      "admin@demo.com"
    when "accountant"
      "accountant@demo.com"
    else
      "admin@demo.com"
    end

    user = User.find_by(email: email)
    if user
      sign_in(user)
      redirect_to authenticated_root_path, notice: "Logged in as #{role.titleize}"
    else
      redirect_to new_user_session_path, alert: "Demo user #{email} not found. Run rails db:seed"
    end
  end

  # Devise uses this callback after successful sign in.
  # We need allow_other_host for tenant redirects like https://subdomain.domain/dashboard.
  def respond_with(resource, _opts = {})
    return super unless user_signed_in?

    redirect_to after_sign_in_path_for(resource), allow_other_host: true
  end
end
