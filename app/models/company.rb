class Company < ApplicationRecord
  COMPANY_CONFIG_DEFAULTS = {
    "payslip_footer_text" => { data_type: "text", value: "This is a computer generated payslip" },
    "require_bank_verification" => { data_type: "boolean", value: "true" },
    "default_payment_method" => { data_type: "string", value: "bank" },
    "payslip_email_subject" => { data_type: "string", value: "Your Payslip for {{month}}" }
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

  has_one_attached :logo

  enum :plan, { free: 0, pro: 1 }, default: :free

  validates :subdomain, presence: true, uniqueness: { case_sensitive: false }, format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/, message: "allows only lowercase letters, numbers, and hyphens" }
  validates :subdomain, exclusion: { in: %w[www app admin api demo], message: "is reserved" }
  validates :primary_color, format: { with: /\A#[0-9a-fA-F]{6}\z/, message: "must be a 6-digit hex color" }

  before_validation :normalize_subdomain
  after_create :seed_company_defaults

  private

  def normalize_subdomain
    self.subdomain = subdomain.to_s.downcase.strip
  end

  def seed_company_defaults
    COMPANY_CONFIG_DEFAULTS.each do |key, details|
      company_configs.find_or_create_by!(key: key) do |cfg|
        cfg.data_type = details[:data_type]
        cfg.value = details[:value]
      end
    end

    PROPERTY_DEFAULTS.each do |property_key, values|
      values.each_with_index do |val, index|
        company_properties.find_or_create_by!(property_key: property_key, value: val) do |prop|
          prop.position = index
        end
      end
    end
  end
end
