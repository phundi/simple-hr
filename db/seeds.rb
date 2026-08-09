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
    value: "hr.com",
    category: "General",
    description: "Base domain for company URLs. Example: hr.com"
  },
  {
    key: "app_name",
    value: "PayslipPro",
    category: "General",
    description: "Used in emails + header"
  },
  {
    key: "support_email",
    value: "support@hr.com",
    category: "Support",
    description: "Support contact"
  },
  {
    key: "smtp_address",
    value: "smtp.sendgrid.net",
    category: "Email",
    description: "System SMTP"
  },
  {
    key: "smtp_port",
    value: "587",
    category: "Email",
    description: "System SMTP Port"
  },
  {
    key: "enable_2fa",
    value: "false",
    category: "Security",
    description: "Allow 2FA for all companies"
  },
  {
    key: "allow_payslip_download",
    value: "true",
    category: "Payroll",
    description: "Employees can download PDF"
  },
  {
    key: "google_analytics_id",
    value: "",
    category: "Tracking",
    description: "G-XXXX for system wide GA"
  },
  {
    key: "enable_subdomain_redirect",
    value: "false",
    category: "Security",
    description: "If true, users are redirected to subdomain.company.com. If false, all users stay on main domain"
  },
  {
    key: "maintenance_mode",
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
  Company::COMPANY_CONFIG_DEFAULTS.each do |key, default_value|
    cfg = company.company_configs.find_or_initialize_by(key: key)
    cfg.value = default_value if cfg.value.blank?
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
    role: :admin,
    super_admin: true,
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

  # Ensure payroll components and defaults are seeded for demo
  begin
    demo_company.send(:seed_company_defaults)
  rescue StandardError
    demo_company.reload
  end

  # Seed company payroll settings with Malawi sample rates
  demo_company.create_company_payroll_setting! unless demo_company.company_payroll_setting
  demo_company.company_payroll_setting.update(
    house_allowance_rate: 0.10,
    pension_employer_rate: 0.10,
    pension_employee_rate: 0.05,
    funeral_rate: 0.01,
    tevet_rate: 0.01,
    life_assurance_rate: 0.01,
    pension_admin_rate: 0.003,
    admin_vat_rate: 0.165,
    paye_brackets: MalawiPayeCalculator::DEFAULT_BRACKETS,
    medical_grades: {}
  )

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

  departments = [ "HR", "Finance", "IT" ]
  job_roles = [ "Manager", "Staff" ]

  # Create eight demo employees with Malawi-like salaries (from PAYROLL_Template sample)
  demo_salaries = [3_051_000, 1_886_230, 1_500_000, 1_200_000, 950_000, 800_000, 600_000, 450_000]
  demo_projects = ['Project A', 'Project B', 'Project A', 'Project C', 'Project B', 'Project A', 'Project D', 'Project B']

  employees = demo_salaries.each_with_index.map do |sal, index|
    payment_method = index.even? ? :bank : :bank
    attrs = {
      company: demo_company,
      employee_code: format("DEMO%03d", index + 1),
      first_name: Faker::Name.first_name,
      last_name: Faker::Name.last_name,
      department: departments[index % departments.length],
      job_title: job_roles[index % job_roles.length],
      salary: sal,
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

  # Create May 2024 pay period (draft) and compute payslips using service to match sample
  period = PayPeriod.find_or_create_by!(company: demo_company, month: 5, year: 2024) do |pay_period|
    pay_period.status = :draft
  end

  total_gross = 0.to_d
  total_net = 0.to_d

  employees.each_with_index do |employee, idx|
    # assign project
    employee.update!(project: demo_projects[idx]) if employee.respond_to?(:project)
    employee_struct = Struct.new(:salary, :medical_grade).new(BigDecimal(employee.salary.to_s), employee.respond_to?(:medical_grade) ? employee.medical_grade : nil)
    settings = demo_company.company_payroll_setting ? {
      house_allowance_rate: demo_company.company_payroll_setting.house_allowance_rate,
      pension_employee_rate: demo_company.company_payroll_setting.pension_employee_rate,
      pension_employer_rate: demo_company.company_payroll_setting.pension_employer_rate,
      funeral_rate: demo_company.company_payroll_setting.funeral_rate,
      tevet_rate: demo_company.company_payroll_setting.tevet_rate,
      life_assurance_rate: demo_company.company_payroll_setting.life_assurance_rate,
      pension_admin_rate: demo_company.company_payroll_setting.pension_admin_rate,
      admin_vat_rate: demo_company.company_payroll_setting.admin_vat_rate,
      paye_brackets: demo_company.company_payroll_setting.paye_brackets || MalawiPayeCalculator::DEFAULT_BRACKETS,
      medical_grades: demo_company.company_payroll_setting.medical_grades || {}
    } : {}

    computation = PayrollComputationService.new(employee_struct, period, settings, employee.employee_advances, employee.employee_payroll_components).call

    payslip = Payslip.find_or_initialize_by(pay_period: period, employee: employee)
    payslip.basic_salary = computation[:basic_salary]
    payslip.allowances = computation[:allowances]
    payslip.employer_benefits = computation[:employer_benefits]
    payslip.total_employer_benefits = computation[:total_employer_benefits]
    payslip.total_remuneration = computation[:total_remuneration]
    payslip.taxable_income = computation[:taxable_income]
    payslip.paye = computation[:deductions_breakdown][:paye]
    payslip.pension_employee = computation[:deductions_breakdown][:pension_employee]
    payslip.gross = computation[:gross_income]
    payslip.net = computation[:net_pay]
    payslip.deductions_breakdown = computation[:deductions_breakdown]
    payslip.save!

    total_gross += payslip.gross.to_d
    total_net += payslip.net.to_d
  end

  period.update!(total_gross: total_gross, total_net: total_net)
  puts "Demo ready at https://demo.#{main_domain}"
end
