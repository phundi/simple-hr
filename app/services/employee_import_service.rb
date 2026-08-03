class EmployeeImportService
  EMPLOYEE_FIELDS = %w[
    first_name
    last_name
    employee_code
    department
    job_title
    salary
    payment_method
    bank_name
    bank_branch
    bank_account_number
    account_type
    account_holder_name
    swift_code
    mobile_money_number
    mobile_money_provider
  ].freeze

  USER_FIELDS = %w[email phone_number].freeze

  def initialize(company:, import_template:, actor: nil)
    @company = company
    @import_template = import_template
    @actor = actor
  end

  def call(rows:, mapping:)
    imported_count = 0
    failed_count = 0

    rows.each_with_index do |row, index|
      company.transaction do
        employee_attrs, user_attrs = mapped_attributes_from_row(row, mapping)
        employee_attrs[:source_row] = index + 2
        employee_attrs[:import_template] = import_template

        user = find_or_create_user!(employee_attrs: employee_attrs, user_attrs: user_attrs)
        employee_attrs[:user] = user if user

        company.employees.create!(employee_attrs)
        imported_count += 1
      end
    rescue ActiveRecord::RecordInvalid
      failed_count += 1
    end

    { imported_count: imported_count, failed_count: failed_count }
  end

  private

  attr_reader :company, :import_template, :actor

  def mapped_attributes_from_row(row, mapping)
    employee_attrs = {}
    user_attrs = {}

    mapping.each do |column_index, field_name|
      raw_value = row[column_index.to_i]
      value = raw_value.is_a?(String) ? raw_value.strip : raw_value
      next if value.blank?

      if USER_FIELDS.include?(field_name)
        user_attrs[field_name.to_sym] = value
        next
      end

      next unless EMPLOYEE_FIELDS.include?(field_name)

      case field_name
      when "salary"
        employee_attrs[:salary] = value.to_s.delete(",").presence
      when "payment_method"
        employee_attrs[:payment_method] = normalize_payment_method(value)
      when "mobile_money_provider"
        employee_attrs[:mobile_money_provider] = normalize_mobile_money_provider(value)
      when "account_type"
        employee_attrs[:account_type] = normalize_account_type(value)
      else
        employee_attrs[field_name.to_sym] = value
      end
    end

    [ employee_attrs, user_attrs ]
  end

  def find_or_create_user!(employee_attrs:, user_attrs:)
    email = user_attrs[:email].to_s.downcase.presence
    phone_number = user_attrs[:phone_number].to_s.presence

    user = if email
      company.users.find_by(email: email)
    elsif phone_number
      company.users.find_by(phone_number: phone_number)
    end

    return user if user

    user = company.users.create!(
      first_name: employee_attrs[:first_name].presence || "Employee",
      last_name: employee_attrs[:last_name].presence || "User",
      email: email,
      phone_number: phone_number,
      status: :invited,
      onboarding_status: :unverified
    )

    user.send_verification!
    user
  end

  def normalize_payment_method(value)
    normalized = value.to_s.downcase.gsub(/\s+/, "_")
    return "bank" if normalized == "bank"
    return "mobile_money" if [ "mobile_money", "mm" ].include?(normalized)

    "cash"
  end

  def normalize_mobile_money_provider(value)
    normalized = value.to_s.downcase
    return "airtel" if normalized.include?("airtel")
    return "tigo" if normalized.include?("tigo") || normalized.include?("tnm") || normalized.include?("mpamba")

    nil
  end

  def normalize_account_type(value)
    normalized = value.to_s.downcase
    return "savings" if normalized.include?("saving")
    return "checking" if normalized.include?("checking") || normalized.include?("current")

    nil
  end
end
