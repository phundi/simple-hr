class SuperAdmin::ApplicationController < ApplicationController
  before_action :authenticate_user!
  before_action :require_super_admin!

  layout "super_admin"

  private

  def require_super_admin!
    return if current_user&.super_admin?

    redirect_to new_user_session_path, alert: "Access denied."
  end
end
