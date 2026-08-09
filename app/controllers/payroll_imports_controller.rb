class PayrollImportsController < ApplicationController
  before_action :authenticate_user!
  before_action -> { authorize!("create_payroll") }
  before_action :authorize_download, only: [:download_template]

  def new
    # simple form offering download or upload
  end

  def create
    uploaded = params.dig(:payroll_import, :file)
    unless uploaded
      redirect_to new_payroll_import_path, alert: "Please choose a file to upload." and return
    end

    service = PayrollImportService.new(current_company, uploaded, current_user)
    result = service.call

    # store parsed rows in session for mapping/preview
    session[:payroll_import] = {
      rows: result[:rows],
      rates: result[:rates],
      uploaded_at: Time.current.to_i,
      filename: uploaded.original_filename
    }

    redirect_to mapping_payroll_imports_path, notice: "File uploaded. Confirm mappings and preview."
  rescue StandardError => e
    redirect_to new_payroll_import_path, alert: "Upload failed: #{e.message}"
  end

  def mapping
    data = session[:payroll_import]
    unless data
      redirect_to new_payroll_import_path, alert: "No uploaded file found. Please upload first." and return
    end

    @headers = data[:rows].first ? data[:rows].first.keys : []
    @rows = data[:rows]
    @rates = data[:rates]
    @mapping_options = ImportTemplatesController::SYSTEM_MAPPING_FIELDS
  end

  def preview
    data = session[:payroll_import]
    unless data
      redirect_to new_payroll_import_path, alert: "No uploaded file found. Please upload first." and return
    end

    # Use company payroll settings
    settings = current_company.respond_to?(:company_payroll_setting) && current_company.company_payroll_setting ? company_settings_hash(current_company.company_payroll_setting) : default_company_settings

    @preview = []
    data[:rows].each do |row|
      # build a fake employee struct for computation
      employee = Struct.new(:salary, :medical_grade).new(row[:basic_salary] || row[:basic] || row[:salary] || 0, row[:medical_grade] || row[:medical])

      result = PayrollComputationService.new(employee, nil, settings, [], []).call
      @preview << result.merge(name: [row[:first_name], row[:last_name]].compact.join(' '))
    end

    @totals = {
      gross: @preview.sum { |r| r[:gross_income] },
      net: @preview.sum { |r| r[:net_pay] }
    }
  end

  def import
    data = session.delete(:payroll_import)
    unless data
      redirect_to new_payroll_import_path, alert: "No uploaded file found. Please upload first." and return
    end

    month = params[:month].to_i
    year = params[:year].to_i
    pay_period = current_company.pay_periods.find_or_create_by!(month: month, year: year)

    settings = current_company.company_payroll_setting || {}

    created = 0
    data[:rows].each do |row|
      emp = find_or_build_employee_from_row(row)
      emp.company = current_company
      emp.save! if emp.changed?

      # compute payslip
      employee_struct = Struct.new(:salary, :medical_grade).new(row[:basic_salary] || row[:basic] || row[:salary] || 0, row[:medical_grade])
      computation = PayrollComputationService.new(employee_struct, pay_period, company_settings_hash(current_company.company_payroll_setting), [], []).call

      payslip = current_company.payslips.new(
        employee: emp,
        pay_period: pay_period,
        basic_salary: computation[:basic_salary],
        allowances: computation[:allowances],
        employer_benefits: computation[:employer_benefits],
        deductions_breakdown: computation[:deductions_breakdown],
        total_employer_benefits: computation[:total_employer_benefits],
        total_remuneration: computation[:total_remuneration],
        taxable_income: computation[:taxable_income],
        paye: computation[:deductions_breakdown][:paye],
        pension_employee: computation[:deductions_breakdown][:pension_employee],
        gross: computation[:gross_income],
        net: computation[:net_pay]
      )

      payslip.save!
      created += 1
    end

    redirect_to pay_period_path(pay_period), notice: "Imported #{created} payslips."
  rescue StandardError => e
    redirect_to new_payroll_import_path, alert: "Import failed: #{e.message}"
  end

  def download_template
    path = ExportStandardTemplateService.new(current_company).call
    send_file path, filename: "payslip_pro_standard_template.xlsx", type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  end

  private

  def authorize_download
    authorize!("export_employee_data")
  end

  def find_or_build_employee_from_row(row)
    code = row[:employee_code] || row[:employee_id]
    emp = if code.present?
            current_company.employees.find_or_initialize_by(employee_code: code)
          else
            names = [row[:first_name], row[:last_name]].compact
            current_company.employees.find_or_initialize_by(first_name: names.first, last_name: names.last)
          end

    emp.first_name ||= row[:first_name]
    emp.last_name ||= row[:last_name]
    emp.email ||= row[:email]
    emp.phone_number ||= row[:phone]
    emp.job_title ||= row[:position]
    emp.department ||= row[:department]
    emp
  end

  def company_settings_hash(settings)
    return {} unless settings
    {
      house_allowance_rate: settings.house_allowance_rate,
      pension_employee_rate: settings.pension_employee_rate,
      pension_employer_rate: settings.pension_employer_rate,
      funeral_rate: settings.funeral_rate,
      tevet_rate: settings.tevet_rate,
      life_assurance_rate: settings.life_assurance_rate,
      pension_admin_rate: settings.pension_admin_rate,
      admin_vat_rate: settings.admin_vat_rate,
      paye_brackets: settings.paye_brackets || MalawiPayeCalculator::DEFAULT_BRACKETS,
      medical_grades: settings.medical_grades || {}
    }
  end

  def default_company_settings
    {
      house_allowance_rate: 0.10,
      pension_employee_rate: 0.05,
      pension_employer_rate: 0.10,
      funeral_rate: 0.01,
      tevet_rate: 0.01,
      life_assurance_rate: 0.01,
      pension_admin_rate: 0.003,
      admin_vat_rate: 0.165,
      paye_brackets: MalawiPayeCalculator::DEFAULT_BRACKETS,
      medical_grades: {}
    }
  end
end
