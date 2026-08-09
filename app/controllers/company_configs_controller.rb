class CompanyConfigsController < ApplicationController
  before_action :ensure_company_admin!
  before_action :set_company_config, only: :update
  # permission_key: manage_company_profile
  before_action -> { authorize!("manage_company_profile") }

  COMPANY_CONFIG_DEFAULTS = {
    "payslip_footer_text" => "This is a computer generated payslip",
    "require_bank_verification" => "true",
    "default_payment_method" => "bank",
    "payslip_email_subject" => "Your Payslip for {{month}}"
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

    @active_tab = params[:tab].presence_in(%w[general lists permissions payroll_settings]) || "general"
    @company_configs = current_company.company_configs.where(key: COMPANY_CONFIG_DEFAULTS.keys).order(:key)
    @company_properties = current_company.company_properties.where(property_key: CompanyProperty::PROPERTY_KEYS).order(:property_key, :position, :value)
    @property_groups = @company_properties.group_by(&:property_key)

    @permission_matrix = {}
    if @active_tab == "permissions"
      RolePermission.where(company_id: current_company.id, role: ROLES, permission_key: PERMISSIONS).find_each do |record|
        @permission_matrix[[record.permission_key, record.role]] = record.enabled
      end
    end

    if @active_tab == "payroll_settings"
      @payroll_settings = current_company.company_payroll_setting || current_company.build_company_payroll_setting
      @payroll_components = current_company.payroll_components.order(:category, :position, :name)
      @components_grouped = @payroll_components.group_by(&:category)
    end
  end

  def update_payroll_settings
    attrs = params.require(:company_payroll_setting).permit(
      :tax_year,
      :tax_free_threshold,
      :house_allowance_auto,
      :house_allowance_rate,
      :pension_employer_rate,
      :pension_employee_rate,
      :funeral_rate,
      :tevet_rate,
      :life_assurance_rate,
      :pension_admin_rate,
      :admin_vat_rate,
      :paye_brackets,
      :medical_grades
    )

    attrs[:paye_brackets] = JSON.parse(attrs[:paye_brackets]) if attrs[:paye_brackets].is_a?(String)
    attrs[:medical_grades] = JSON.parse(attrs[:medical_grades]) if attrs[:medical_grades].is_a?(String)

    setting = current_company.company_payroll_setting || current_company.build_company_payroll_setting
    if setting.update(attrs)
      redirect_to company_configs_path(tab: 'payroll_settings'), notice: 'Payroll settings saved.'
    else
      redirect_to company_configs_path(tab: 'payroll_settings'), alert: setting.errors.full_messages.to_sentence
    end
  end

    def create_payroll_component
      attrs = params.require(:payroll_component).permit(:name, :code, :category, :calculation_type, :default_rate, :default_amount, :taxable, :enabled_by_default, :position)
      comp = current_company.payroll_components.new(attrs)
      if comp.save
        redirect_to company_configs_path(tab: 'payroll_settings'), notice: 'Component added.'
      else
        redirect_to company_configs_path(tab: 'payroll_settings'), alert: comp.errors.full_messages.to_sentence
      end
    end

    def update_payroll_component
      comp = current_company.payroll_components.find(params[:id])
      attrs = params.require(:payroll_component).permit(:name, :code, :category, :calculation_type, :default_rate, :default_amount, :taxable, :enabled_by_default, :position)
      if comp.update(attrs)
        redirect_to company_configs_path(tab: 'payroll_settings'), notice: 'Component updated.'
      else
        redirect_to company_configs_path(tab: 'payroll_settings'), alert: comp.errors.full_messages.to_sentence
      end
    end

    def toggle_payroll_component
      comp = current_company.payroll_components.find(params[:id])
      comp.enabled_by_default = !comp.enabled_by_default
      comp.save!
      redirect_to company_configs_path(tab: 'payroll_settings'), notice: 'Component toggled.'
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
    if @company_config.update(value: config_update_params[:value].to_s.strip)
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
    return if current_user&.admin? || current_user&.super_admin?

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

  def seed_company_defaults!
    COMPANY_CONFIG_DEFAULTS.each do |key, default_value|
      cfg = current_company.company_configs.find_or_initialize_by(key: key)
      cfg.value = default_value if cfg.new_record?
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
