class ImportTemplatesController < ApplicationController
  SYSTEM_MAPPING_FIELDS = [
    [ "Ignore", "" ],
    [ "First Name", "first_name" ],
    [ "Last Name", "last_name" ],
    [ "Employee Code", "employee_code" ],
    [ "Email", "email" ],
    [ "Phone Number", "phone_number" ],
    [ "Department", "department" ],
    [ "Job Title", "job_title" ],
    [ "Salary", "salary" ],
    [ "Payment Method", "payment_method" ],
    [ "Bank Name", "bank_name" ],
    [ "Bank Branch", "bank_branch" ],
    [ "Bank Account Number", "bank_account_number" ],
    [ "Account Type", "account_type" ],
    [ "Account Holder Name", "account_holder_name" ],
    [ "SWIFT Code", "swift_code" ],
    [ "Mobile Money Number", "mobile_money_number" ],
    [ "Mobile Money Provider", "mobile_money_provider" ]
  ].freeze

  before_action :set_import_template, only: [ :preview, :import ]

  def new
    @import_template = ImportTemplate.new
  end

  def download_sample
    package = Axlsx::Package.new

    package.workbook.add_worksheet(name: "Employees") do |sheet|
      sheet.add_row(sample_template_headers)
      sample_template_rows.each { |row| sheet.add_row(row) }
    end

    send_data package.to_stream.read,
              filename: "PayslipPro_Employee_Template_v1.2.xlsx",
              type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  end

  def create
    @import_template = current_company.import_templates.new(import_template_params)
    @import_template.status = :draft
    @import_template.creator = current_user if current_user

    if @import_template.save
      if @import_template.file.attached?
        redirect_to preview_import_template_path(@import_template), notice: "File uploaded. Map columns and import."
      else
        @import_template.destroy
        flash.now[:alert] = "Please choose a file to upload."
        render :new, status: :unprocessable_entity
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def preview
    @headers, @preview_rows = load_spreadsheet_rows(@import_template.file, preview: true)
    @saved_mapping = @import_template.column_mapping || {}
    @mapping_options = SYSTEM_MAPPING_FIELDS
  rescue StandardError => e
    redirect_to new_import_template_path, alert: "Could not preview file: #{e.message}"
  end

  def import
    mapping = permitted_mapping
    if mapping.blank?
      redirect_to preview_import_template_path(@import_template), alert: "Please map at least one column before importing."
      return
    end

    _, rows = load_spreadsheet_rows(@import_template.file, preview: false)
    result = EmployeeImportService.new(
      company: current_company,
      import_template: @import_template,
      actor: current_user
    ).call(rows: rows, mapping: mapping)

    imported_count = result.fetch(:imported_count)
    failed_count = result.fetch(:failed_count)

    @import_template.update!(column_mapping: mapping, status: :active)
    redirect_to preview_import_template_path(@import_template), notice: "Imported #{imported_count} employees. Failed #{failed_count}."
  rescue StandardError => e
    redirect_to preview_import_template_path(@import_template), alert: "Import failed: #{e.message}"
  end

  private

  def set_import_template
    @import_template = current_company.import_templates.find(params[:id])
  end

  def import_template_params
    params.require(:import_template).permit(:name, :file)
  end

  def permitted_mapping
    raw_mapping = params.fetch(:mapping, {}).to_unsafe_h
    allowed_fields = SYSTEM_MAPPING_FIELDS.map(&:last)
    raw_mapping.each_with_object({}) do |(column_index, field_name), result|
      next if field_name.blank? || !allowed_fields.include?(field_name)

      result[column_index] = field_name
    end
  end

  def current_user
    User.first
  end

  def load_spreadsheet_rows(attached_file, preview:)
    raise "No file attached" unless attached_file.attached?

    rows = attached_file.blob.open do |temp_file|
      extension = File.extname(attached_file.filename.to_s).downcase
      case extension
      when ".csv"
        parse_csv(temp_file.path)
      when ".xlsx", ".xls"
        parse_excel(temp_file.path)
      else
        raise "Unsupported file type: #{extension}. Use CSV or XLSX."
      end
    end

    headers = rows.first || []
    data_rows = rows.drop(1)
    data_rows = data_rows.first(5) if preview

    [ headers, data_rows ]
  end

  def parse_csv(path)
    require "csv"

    CSV.read(path, headers: false).map(&:to_a)
  end

  def parse_excel(path)
    spreadsheet = Roo::Spreadsheet.open(path)
    spreadsheet.sheet(0).parse(headers: false)
  end

  def sample_template_headers
    [
      "First Name",
      "Last Name",
      "Employee Code",
      "Phone",
      "Email",
      "Department",
      "Job Title",
      "Salary",
      "Payment Method",
      "Bank Name",
      "Account Number",
      "Mobile Money Number",
      "Mobile Money Provider"
    ]
  end

  def sample_template_rows
    [
      [ "John", "Banda", "E001", "0999123456", "john@co.mw", "Ops", "Driver", 150000, "bank", "NBM", "12345678", nil, nil ],
      [ "Mary", "Phiri", "E002", "0888123456", "mary@co.mw", "Finance", "Accountant", 350000, "mobile_money", nil, nil, "0888123456", "airtel" ]
    ]
  end
end
