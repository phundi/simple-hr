namespace :role_permissions do
  DEFAULTS_PATH = Rails.root.join("config", "role_permission_defaults.yml")

  def fallback_defaults
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
      ],
      "hr" => %w[
        manage_employees
        view_payroll
        create_payroll
        export_payslips
        view_reports
      ],
      "accountant" => %w[
        view_payroll
        process_payroll
        export_bank_schedule
        export_paye_schedule
        view_reports
      ]
    }
  end

  def load_defaults
    return fallback_defaults unless File.exist?(DEFAULTS_PATH)

    yaml = YAML.safe_load_file(DEFAULTS_PATH) || {}
    yaml.fetch("roles", {}).transform_values { |vals| Array(vals).map(&:to_s).uniq }
  rescue Psych::Exception
    fallback_defaults
  end

  desc "Export current role permissions from a company to config/role_permission_defaults.yml"
  task :export_defaults, [ :company_id ] => :environment do |_task, args|
    company = if args[:company_id].present?
      Company.find_by(id: args[:company_id])
    else
      Company.joins(:role_permissions)
        .group("companies.id")
        .order(Arel.sql("COUNT(role_permissions.id) DESC"))
        .first
    end

    if company.blank?
      puts "No company with role permissions found."
      next
    end

    roles = User.roles.keys
    grouped = company.role_permissions.where(role: roles).group_by(&:role)
    exported = roles.index_with do |role|
      grouped.fetch(role, []).select(&:enabled).map(&:permission_key).sort
    end

    payload = { "roles" => exported }
    File.write(DEFAULTS_PATH, payload.to_yaml)

    puts "Exported role permissions from company ##{company.id} (#{company.name}) to #{DEFAULTS_PATH}."
  end

  desc "Seed default role permissions for all companies"
  task seed_defaults: :environment do
    defaults = load_defaults

    all_permissions = defaults.values.flatten.uniq

    Company.find_each do |company|
      User.roles.keys.each do |role|
        all_permissions.each do |permission_key|
          enabled = defaults.fetch(role, []).include?(permission_key)
          record = RolePermission.find_or_initialize_by(
            company_id: company.id,
            role: role,
            permission_key: permission_key
          )
          record.enabled = enabled
          record.save! if record.changed?
        end
      end
    end

    puts "Default role permissions seeded for #{Company.count} companies."
  end
end
