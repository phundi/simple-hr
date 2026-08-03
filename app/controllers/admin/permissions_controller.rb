class Admin::PermissionsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_company_admin!

  ROLES = %w[admin hr accountant].freeze
  PERMISSIONS = %w[
    manage_users
    manage_roles
    manage_company_profile
    view_payroll
    create_payroll
    edit_payroll
    process_payroll
    delete_payroll
    manage_employees
    view_employee_sensitive
    export_employee_data
    export_bank_schedule
    export_paye_schedule
    export_payslips
    view_reports
    manage_payroll_settings
    manage_email_templates
  ].freeze

  def index
    redirect_to company_configs_path(tab: "permissions")
  end

  def update
    redirect_to company_configs_path(tab: "permissions")
  end

  private

  def ensure_company_admin!
    return if current_user&.admin?

    redirect_to authenticated_root_path, alert: "Access denied."
  end
end
