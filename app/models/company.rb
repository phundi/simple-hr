class Company < ApplicationRecord
  COMPANY_CONFIG_DEFAULTS = {
    "payslip_footer_text" => "This is a computer generated payslip",
    "require_bank_verification" => "true",
    "default_payment_method" => "bank",
    "payslip_email_subject" => "Your Payslip for {{month}}"
  }.freeze

  PROPERTY_DEFAULTS = {
    "department" => [ "General" ],
    "employee_role" => [ "Employee" ],
    "payment_method" => [ "Bank", "Mobile Money", "Cash" ]
  }.freeze

  has_many :users, dependent: :destroy
  has_many :employees, dependent: :destroy
  has_many :import_templates, dependent: :destroy
  has_many :pay_periods, dependent: :destroy
  has_many :company_configs, dependent: :destroy
  has_many :company_properties, dependent: :destroy
  has_many :role_permissions, dependent: :destroy
  has_many :payroll_components, dependent: :destroy
  has_many :employee_advances, dependent: :destroy
  has_one :company_payroll_setting, dependent: :destroy

  has_one_attached :logo

  enum :plan, { free: 0, pro: 1 }, default: :free

  validates :subdomain, presence: true, uniqueness: { case_sensitive: false }, format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/, message: "allows only lowercase letters, numbers, and hyphens" }
  validates :subdomain, exclusion: { in: %w[www app admin api demo], message: "is reserved" }, if: :validate_reserved_subdomain?
  validates :primary_color, format: { with: /\A#[0-9a-fA-F]{6}\z/, message: "must be a 6-digit hex color" }

  before_validation :normalize_subdomain
  after_create :seed_company_defaults
  after_create :seed_default_role_permissions

  private

  def normalize_subdomain
    self.subdomain = subdomain.to_s.downcase.strip
  end

  def validate_reserved_subdomain?
    new_record? || will_save_change_to_subdomain?
  end

  def seed_company_defaults
    COMPANY_CONFIG_DEFAULTS.each do |key, default_value|
      company_configs.find_or_create_by!(key: key) do |cfg|
        cfg.value = default_value
      end
    end

    PROPERTY_DEFAULTS.each do |property_key, values|
      values.each_with_index do |val, index|
        company_properties.find_or_create_by!(property_key: property_key, value: val) do |prop|
          prop.position = index
        end
      end
    end

    # Seed payroll settings defaults
    seed_company_payroll_settings_defaults

    # Seed payroll components defaults
    seed_payroll_components_defaults
  end

  def seed_company_payroll_settings_defaults
    return if company_payroll_setting.present?

    create_company_payroll_setting!(
      tax_year: Date.current.year.to_s,
      tax_free_threshold: 100_000,
      house_allowance_auto: true,
      house_allowance_rate: 0.10,
      pension_employer_rate: 0.10,
      pension_employee_rate: 0.05,
      funeral_rate: 0.01,
      tevet_rate: 0.01,
      life_assurance_rate: 0.01,
      pension_admin_rate: 0.003,
      admin_vat_rate: 0.165,
      paye_brackets: CompanyPayrollSetting::DEFAULT_BRACKETS,
      medical_grades: {}
    )
  end

  def seed_default_role_permissions
    defaults = role_permission_defaults

    all_permissions = defaults.values.flatten.uniq

    User.roles.keys.each do |role|
      all_permissions.each do |permission_key|
        role_permissions.find_or_create_by!(role: role, permission_key: permission_key) do |permission|
          permission.enabled = defaults.fetch(role, []).include?(permission_key)
        end
      end
    end
  end

  def seed_payroll_components_defaults
    return unless payroll_components.empty?

    # Allowances
    payroll_components.create!(name: 'House Allowance', code: 'house_allowance', category: 'allowance', calculation_type: 'percent_basic', default_rate: 0.10)
    payroll_components.create!(name: 'Transport', code: 'transport', category: 'allowance', calculation_type: 'fixed', default_amount: 0)
    payroll_components.create!(name: 'Overtime', code: 'overtime', category: 'allowance', calculation_type: 'fixed', default_amount: 0)

    # Employer benefits
    payroll_components.create!(name: 'Medical', code: 'medical', category: 'employer_benefit', calculation_type: 'fixed_by_grade')
    payroll_components.create!(name: 'Pension Employer', code: 'pension_employer', category: 'employer_benefit', calculation_type: 'percent_basic', default_rate: 0.10)
    payroll_components.create!(name: 'Funeral Cover', code: 'funeral', category: 'employer_benefit', calculation_type: 'percent_basic', default_rate: 0.01)
    payroll_components.create!(name: 'Tevet Levy', code: 'tevet', category: 'employer_benefit', calculation_type: 'percent_basic', default_rate: 0.01)
    payroll_components.create!(name: 'Life Assurance', code: 'life_assurance', category: 'employer_benefit', calculation_type: 'percent_basic', default_rate: 0.01)
    payroll_components.create!(name: 'Pension Admin', code: 'pension_admin', category: 'employer_benefit', calculation_type: 'percent_basic', default_rate: 0.003)
    payroll_components.create!(name: 'Pension Admin VAT', code: 'pension_admin_vat', category: 'employer_benefit', calculation_type: 'percent_basic', default_rate: 0.165)

    # Statutory / deductions
    payroll_components.create!(name: 'PAYE', code: 'paye', category: 'statutory', calculation_type: 'fixed')
    payroll_components.create!(name: 'Pension Employee', code: 'pension_employee', category: 'deduction', calculation_type: 'percent_gross', default_rate: 0.05)
    payroll_components.create!(name: 'Salary Advance', code: 'salary_advance', category: 'deduction', calculation_type: 'fixed')
  rescue StandardError
    # Do not raise in seed
    nil
  end

  def role_permission_defaults
    path = Rails.root.join("config", "role_permission_defaults.yml")

    if File.exist?(path)
      yaml = YAML.safe_load_file(path) || {}
      roles = yaml.fetch("roles", {})
      return roles.transform_values { |vals| Array(vals).map(&:to_s).uniq } if roles.present?
    end

    fallback_role_permission_defaults
  rescue Psych::Exception
    fallback_role_permission_defaults
  end

  def fallback_role_permission_defaults
    {
      "admin" => %w[
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
        manage_payroll_components
        view_employer_benefits
      ],
      "hr" => %w[
        manage_employees
        view_payroll
        create_payroll
        export_payslips
        view_reports
        manage_payroll_components
        view_employer_benefits
      ],
      "accountant" => %w[
        view_payroll
        process_payroll
        export_bank_schedule
        export_paye_schedule
        view_reports
        view_employer_benefits
      ]
    }
  end
end
