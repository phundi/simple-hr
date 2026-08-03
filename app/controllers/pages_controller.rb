class PagesController < ApplicationController
  layout "public"
  skip_before_action :authenticate_user!, only: :landing

  def landing
    redirect_to authenticated_root_path if user_signed_in?
  end

  def payroll
  end

  def settings
  end
end
