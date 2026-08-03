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
    description: "Base domain for company URLs. Example: hr.com"
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
    key: "enable_subdomain_redirect",
    data_type: "boolean",
    value: "false",
    category: "Security",
    description: "If true, users are redirected to subdomain.company.com. If false, all users stay on main domain"
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
  default_company = Company.find_or_create_by!(subdomain: "default-company") do |company|
    company.name = "Default Company"
    company.primary_color = "#0d6efd"
  end

  existing_user = User.find_by(email: "kennethkapundi1@gmail.com")
  if existing_user && existing_user.id != first_user.id
    existing_user.update!(email: "legacy_user_#{existing_user.id}@example.com")
  end

  first_user.update!(
    email: "kennethkapundi1@gmail.com",
    first_name: "Kenneth",
    last_name: "Kapundi",
    phone_number: "0991763413",
    role: :super_admin,
    company: default_company,
    password: "password",
    password_confirmation: "password"
  )
end

ActiveRecord::Base.transaction do
  require "faker"

  main_domain = ConfigService.get(nil, nil, "main_domain").presence || "hr.com"

  # `demo` is reserved by Company validation in this app, so bootstrap once without validations.
  unless Company.exists?(subdomain: "demo")
    Company.new(subdomain: "demo", name: "Demo Company").tap do |company|
      company.primary_color = "#206bc4"
      company.save!(validate: false)
    end
  end

  demo_company = Company.find_or_create_by!(subdomain: "demo", name: "Demo Company")
  demo_company.update_columns(name: "Demo Company", primary_color: "#206bc4")

  demo_emails = [ "admin@demo.com", "hr@demo.com", "login@demo.com", "accountant@demo.com", "accounts@demo.com", "employee@demo.com" ]

  # Reset demo tenant user/employee/payroll data when rerunning seeds.
  Payslip.joins(:pay_period).where(pay_periods: { company_id: demo_company.id }).delete_all
  demo_company.employees.delete_all
  demo_company.pay_periods.delete_all
  demo_company.users.where(email: demo_emails).delete_all

  if defined?(CompanyRole) && CompanyRole.table_exists?
    [ "admin", "hr_manager", "accountant", "employee" ].each do |role_name|
      CompanyRole.find_or_create_by!(company: demo_company, name: role_name)
    end
  end

  {
    "department" => [ "HR", "Finance", "IT" ],
    "employee_role" => [ "Manager", "Staff" ],
    "payment_method" => [ "Bank", "Cash" ]
  }.each do |property_key, values|
    values.each_with_index do |value, position|
      CompanyProperty.find_or_create_by!(company: demo_company, property_key: property_key, value: value) do |prop|
        prop.position = position
      end
    end
  end

  # Only create users for enum roles available in this app (admin/hr/accountant).
  [
    { email: "admin@demo.com", password: "admin", role: :admin, first_name: "Demo", last_name: "Admin" },
    { email: "hr@demo.com", password: "hr", role: :hr, first_name: "Demo", last_name: "HR" },
    { email: "login@demo.com", password: "login", role: :admin, first_name: "Demo", last_name: "Login" },
    { email: "accountant@demo.com", password: "accountant", role: :accountant, first_name: "Demo", last_name: "Accountant" },
    { email: "accounts@demo.com", password: "accounts", role: :accountant, first_name: "Demo", last_name: "Accounts" }
  ].each do |attrs|
    user = User.find_or_initialize_by(company: demo_company, email: attrs[:email])
    user.assign_attributes(
      first_name: attrs[:first_name],
      last_name: attrs[:last_name],
      role: attrs[:role],
      status: :active,
      onboarding_status: :verified,
      password: attrs[:password],
      password_confirmation: attrs[:password]
    )
    user.skip_confirmation! if user.respond_to?(:skip_confirmation!)
    # Devise length validation can reject short demo passwords (e.g. "hr"); we still set encrypted_password via Devise.
    user.save!(validate: false)
  end

  unless User.roles.key?("employee")
    puts "Skipping employee demo user: User.role enum does not include :employee"
  end

  departments = [ "HR", "Finance", "IT" ]
  job_roles = [ "Manager", "Staff" ]

  employees = 5.times.map do |index|
    payment_method = index.even? ? :bank : :cash
    attrs = {
      company: demo_company,
      employee_code: format("DEMO%03d", index + 1),
      first_name: Faker::Name.first_name,
      last_name: Faker::Name.last_name,
      department: departments[index % departments.length],
      job_title: job_roles[index % job_roles.length],
      salary: (1500 + (index * 250)),
      payment_method: payment_method,
      employment_status: :active,
      onboarding_status: :verified
    }

    if payment_method == :bank
      attrs[:bank_name] = "Demo Bank"
      attrs[:bank_account_number] = format("1000%03d", index + 1)
    end

    Employee.create!(attrs)
  end

  period = PayPeriod.find_or_create_by!(company: demo_company, month: Date.current.month, year: Date.current.year) do |pay_period|
    pay_period.status = :published
    pay_period.total_gross = 0
    pay_period.total_net = 0
  end

  period.update!(status: :published, total_gross: 0, total_net: 0)

  total_gross = 0.to_d
  total_net = 0.to_d

  employees.first(2).each do |employee|
    gross = employee.salary.to_d
    deductions = (gross * 0.12).round(2)
    net = gross - deductions

    Payslip.find_or_create_by!(pay_period: period, employee: employee) do |payslip|
      payslip.gross = gross
      payslip.deductions = deductions
      payslip.net = net
    end

    total_gross += gross
    total_net += net
  end

  period.update!(total_gross: total_gross, total_net: total_net)
  puts "Demo ready at https://demo.#{main_domain}"
end
