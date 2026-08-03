class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :set_current_company
  # Temporarily disabled to keep navigation on localhost during local testing.
  # before_action :redirect_to_subdomain_host, if: :redirect_to_company_host?
  helper_method :current_company, :main_domain, :company_main_domain

  private

  def set_current_company
    @current_company = company_from_request_subdomain || company_from_current_user || default_company
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

  def company_from_current_user
    current_user&.company
  end

  def extract_subdomain
    host = request.host.to_s.downcase
    return nil if host.blank? || host == "localhost" || host.match?(/\A\d+\.\d+\.\d+\.\d+\z/)

    parts = host.split(".")
    return nil if parts.size < 3

    sub = parts.first
    return nil if [ "www" ].include?(sub)

    sub
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
