# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

system_configs = [
  {
    key: "main_domain",
    data_type: "string",
    value: "hr.com",
    category: "General",
    description: "Base domain for subdomains"
  },
  {
    key: "app_name",
    data_type: "string",
    value: "PayslipPro",
    category: "General",
    description: "Used in emails + header"
  },
  {
    key: "support_email",
    data_type: "string",
    value: "support@hr.com",
    category: "Support",
    description: "Support contact"
  },
  {
    key: "smtp_address",
    data_type: "string",
    value: "smtp.sendgrid.net",
    category: "Email",
    description: "System SMTP"
  },
  {
    key: "smtp_port",
    data_type: "number",
    value: "587",
    category: "Email",
    description: "System SMTP Port"
  },
  {
    key: "enable_2fa",
    data_type: "boolean",
    value: "false",
    category: "Security",
    description: "Allow 2FA for all companies"
  },
  {
    key: "allow_payslip_download",
    data_type: "boolean",
    value: "true",
    category: "Payroll",
    description: "Employees can download PDF"
  },
  {
    key: "google_analytics_id",
    data_type: "string",
    value: "",
    category: "Tracking",
    description: "G-XXXX for system wide GA"
  },
  {
    key: "maintenance_mode",
    data_type: "boolean",
    value: "false",
    category: "Security",
    description: "Lock system for admin only"
  }
]

system_configs.each do |config_attrs|
  config = SystemConfig.find_or_initialize_by(key: config_attrs[:key])
  config.assign_attributes(config_attrs)
  config.save!
end

Company.find_each do |company|
  Company::COMPANY_CONFIG_DEFAULTS.each do |key, details|
    cfg = company.company_configs.find_or_initialize_by(key: key)
    cfg.data_type = details[:data_type]
    cfg.value = details[:value] if cfg.value.blank?
    cfg.save! if cfg.changed?
  end

  Company::PROPERTY_DEFAULTS.each do |property_key, values|
    values.each_with_index do |value, position|
      prop = company.company_properties.find_or_initialize_by(property_key: property_key, value: value)
      prop.position = position
      prop.save! if prop.changed?
    end
  end
end

first_user = User.order(:id).first
if first_user
  existing_user = User.find_by(email: "kennethkapundi1@gmail.com")
  if existing_user && existing_user.id != first_user.id
    existing_user.update!(email: "legacy_user_#{existing_user.id}@example.com")
  end

  first_user.update!(
    email: "kennethkapundi1@gmail.com",
    first_name: "Kenneth",
    last_name: "Kapundi",
    phone_number: "0991763413"
  )
end
