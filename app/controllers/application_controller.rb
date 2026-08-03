class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :authenticate_user!, unless: :devise_controller?
  before_action :set_current_company, if: :user_signed_in?
  # Temporarily disabled to keep navigation on localhost during local testing.
  # before_action :redirect_to_subdomain_host, if: :redirect_to_company_host?
  helper_method :current_company, :main_domain, :company_main_domain, :authorize!

  def after_sign_in_path_for(resource)
    user = resource.is_a?(User) ? resource : current_user
    return authenticated_root_path if user&.super_admin?
    return authenticated_root_path unless user&.company

    if Rails.env.production? && user.company.subdomain == "demo"
      "https://demo.#{ConfigService.get(nil,nil,'main_domain')}/dashboard"
    else
      authenticated_root_path
    end
  end

  def authorize!(permission)
    return if current_user&.super_admin?
    return if current_user&.can?(permission)

    redirect_to authenticated_root_path, alert: "You don't have permission to do that"
  end

  def authorize_permission!(perm)
    authorize!(perm)
  end

  private

  def set_current_company
    return unless user_signed_in?

    if current_user.super_admin? && session[:super_admin_user_id].blank?
      @current_company = nil
      return
    end

    if Rails.env.development? || request.host.to_s.include?("localhost")
      @current_company = current_user.company
      return
    end

    if request.host.to_s.start_with?("demo.")
      @current_company = Company.find_by(subdomain: "demo")
    else
      @current_company = current_user.company
    end
  end

  def current_company
    @current_company
  end

  def main_domain
    ConfigService.get(nil, nil, "main_domain").presence || "hr.com"
  end

  def company_main_domain(company)
    ConfigService.get(nil, company, "main_domain").presence || main_domain
  end

  def company_from_request_subdomain
    sub = extract_subdomain
    return nil if sub.blank?

    Company.find_by(subdomain: sub)
  end

  def default_company
    Company.find_or_create_by!(subdomain: "default-company") do |company|
      company.name = "Default Company"
      company.primary_color = "#0d6efd"
    end
  end

  def redirect_to_company_host?
    return false unless current_user && current_company
    return false unless request.format.html?
    return false unless request.get?

    request.host != expected_company_host
  end

  def expected_company_host
    "#{current_company.subdomain}.#{company_main_domain(current_company)}"
  end

  def redirect_to_subdomain_host
    redirect_to "https://#{expected_company_host}#{request.fullpath}", allow_other_host: true
  end
end
