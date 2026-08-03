class CompanyConfigsController < ApplicationController
  before_action :ensure_company_admin!
  before_action :set_company_config, only: :update
  # permission_key: manage_company_profile
  before_action -> { authorize!("manage_company_profile") }

  COMPANY_CONFIG_DEFAULTS = {
    "payslip_footer_text" => { data_type: "text", value: "This is a computer generated payslip" },
    "require_bank_verification" => { data_type: "boolean", value: "true" },
    "default_payment_method" => { data_type: "string", value: "bank" },
    "payslip_email_subject" => { data_type: "string", value: "Your Payslip for {{month}}" }
  }.freeze
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
    seed_company_defaults!
    seed_property_buckets!

    @active_tab = params[:tab].presence_in(%w[general lists permissions]) || "general"
    @company_configs = current_company.company_configs.where(key: COMPANY_CONFIG_DEFAULTS.keys).order(:key)
    @company_properties = current_company.company_properties.where(property_key: CompanyProperty::PROPERTY_KEYS).order(:property_key, :position, :value)
    @property_groups = @company_properties.group_by(&:property_key)

    @permission_matrix = {}
    if @active_tab == "permissions"
      RolePermission.where(company_id: current_company.id, role: ROLES, permission_key: PERMISSIONS).find_each do |record|
        @permission_matrix[[record.permission_key, record.role]] = record.enabled
      end
    end
  end

  def update_permissions
    submitted = params.fetch(:permissions, {})

    ActiveRecord::Base.transaction do
      PERMISSIONS.each do |permission_key|
        role_state = submitted.fetch(permission_key, {})

        ROLES.each do |role|
          enabled = ActiveModel::Type::Boolean.new.cast(role_state[role]) == true
          record = RolePermission.find_or_initialize_by(
            company_id: current_company.id,
            role: role,
            permission_key: permission_key
          )
          record.enabled = enabled
          record.save!
        end
      end
    end

    redirect_to company_configs_path(tab: "permissions"), notice: "Permissions updated successfully."
  end

  def create_property
    property_key = property_params[:property_key]
    value = property_params[:value]

    existing_count = current_company.company_properties.where(property_key: property_key).count
    property = current_company.company_properties.new(
      property_key: property_key,
      value: value,
      position: existing_count
    )

    if property.save
      redirect_to company_configs_path(tab: "lists"), notice: "List item added."
    else
      redirect_to company_configs_path(tab: "lists"), alert: property.errors.full_messages.to_sentence
    end
  end

  def update
    new_value = normalize_value(@company_config.data_type, config_update_params[:value])

    if @company_config.update(value: new_value)
      redirect_to company_configs_path(tab: "general"), notice: "Company config updated."
    else
      redirect_to company_configs_path(tab: "general"), alert: @company_config.errors.full_messages.to_sentence
    end
  end

  def update_theme
    if current_company.update(primary_color: theme_params[:primary_color])
      redirect_to company_configs_path(tab: "general"), notice: "Theme color updated."
    else
      redirect_to company_configs_path(tab: "general"), alert: current_company.errors.full_messages.to_sentence
    end
  end

  def destroy_property
    property = current_company.company_properties.find_by(id: params[:id])

    if property
      property.destroy!
      redirect_to company_configs_path(tab: "lists"), notice: "List item removed."
    else
      redirect_to company_configs_path(tab: "lists"), alert: "List item not found."
    end
  end

  private

  def ensure_company_admin!
    return if current_user&.admin? || current_user&.hr?

    redirect_to authenticated_root_path, alert: "Access denied."
  end

  def set_company_config
    @company_config = current_company.company_configs.find(params[:id])
  end

  def config_update_params
    params.require(:company_config).permit(:value)
  end

  def theme_params
    params.require(:company).permit(:primary_color)
  end

  def property_params
    params.require(:company_property).permit(:property_key, :value)
  end

  def normalize_value(data_type, raw_value)
    case data_type
    when "boolean"
      ActiveModel::Type::Boolean.new.cast(raw_value) ? "true" : "false"
    else
      raw_value.to_s.strip
    end
  end

  def seed_company_defaults!
    COMPANY_CONFIG_DEFAULTS.each do |key, details|
      cfg = current_company.company_configs.find_or_initialize_by(key: key)
      cfg.data_type = details[:data_type]
      cfg.value = details[:value] if cfg.new_record?
      cfg.save! if cfg.changed?
    end
  end

  def seed_property_buckets!
    CompanyProperty::PROPERTY_KEYS.each do |key|
      next if current_company.company_properties.exists?(property_key: key)

      current_company.company_properties.create!(property_key: key, value: key.humanize, position: 0)
    end
  end
end
