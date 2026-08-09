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
    styles = package.workbook.styles
    header_style = styles.add_style(b: true, fg_color: 'FFFFFF', bg_color: '2563EB', alignment: { horizontal: :center, vertical: :center })

    package.workbook.add_worksheet(name: "Employees") do |sheet|
      sheet.add_row(sample_template_headers, style: header_style)
      sample_template_rows.each { |row| sheet.add_row(row) }
      sheet.freeze_panes = "A2"
      sheet.auto_filter = "A1:AA1"
      sheet.column_widths(*Array.new(sample_template_headers.size, 18))

      sheet.add_data_validation("K2:K100", type: :list, formula1: '"Active,Blocked,On Leave"', showDropDown: false)
      sheet.add_data_validation("O2:O100", type: :list, formula1: '"bank,mobile_money,cash"', showDropDown: false)
      sheet.add_data_validation("S2:S100", type: :list, formula1: '"Savings,Checking"', showDropDown: false)
      sheet.add_data_validation("U2:U100", type: :list, formula1: '"Airtel Money,TNM Mpamba,None"', showDropDown: false)
      sheet.add_data_validation("V2:V100", type: :list, formula1: '"Grade A,Grade B,Grade C,None"', showDropDown: false)
      sheet.add_data_validation("W2:W100", type: :list, formula1: '"Y,N"', showDropDown: false)
      sheet.add_data_validation("X2:X100", type: :list, formula1: '"Y,N"', showDropDown: false)
      sheet.add_data_validation("Y2:Y100", type: :list, formula1: '"Y,N"', showDropDown: false)
    end

    package.workbook.add_worksheet(name: "Allowances Guide") do |sheet|
      sheet.add_row(["Allowance Type", "Calculation", "Example", "Taxable?", "Notes"], style: header_style)
      sheet.add_row(["Basic Salary", "Fixed", "750,000", "Yes", "Base salary before allowances"])
      sheet.add_row(["House Allowance", "Percentage of basic", "10%", "Yes", "Use company-defined rate when not provided"])
      sheet.add_row(["Other Allowances", "Fixed MWK", "50,000", "Depends", "Additional allowances such as transport or risk"])
      sheet.add_row(["Gross Income", "Basic + allowances", "825,000", "Yes", "Total taxable earnings before deductions"])
      sheet.add_row(["Medical", "Grade-based fixed", "Grade B = 50,000", "No", "Optional medical benefit"])
      sheet.add_row(["Pension Employer", "10% of basic", "75,000", "No", "Employer contribution separate from employee pension"])
      sheet.add_row(["Funeral", "1% of basic", "7,500", "No", "Employer funeral benefit"])
      sheet.add_row(["Tevet", "1% of basic", "7,500", "No", "Tevet levy on salary"])
      sheet.add_row(["Life Assurance", "1% of basic", "7,500", "No", "Employer life cover"])
      sheet.add_row(["Admin", "0.36% of basic", "2,700", "No", "Pension administration charge"])
      sheet.column_widths(24, 24, 18, 12, 32)
      sheet.freeze_panes = "A2"
      sheet.auto_filter = "A1:E1"
    end

    package.workbook.add_worksheet(name: "Deductions Guide") do |sheet|
      sheet.add_row(["Deduction", "Calculation", "Example", "Notes"], style: header_style)
      sheet.add_row(["PAYE", "Based on taxable income", "See PAYE brackets", "Income tax due to Malawi Revenue Authority"])
      sheet.add_row(["Pension Employee", "5% of gross", "41,250", "Employee pension contribution"])
      sheet.add_row(["Advance", "Fixed amount", "20,000", "Loan or cash advance recovery"])
      sheet.add_row(["Net Pay", "Gross - deductions", "756,250", "Take-home pay after all deductions"])
      sheet.column_widths(24, 24, 18, 32)
      sheet.freeze_panes = "A2"
      sheet.auto_filter = "A1:D1"
    end

    package.workbook.add_worksheet(name: "PAYE Brackets MW") do |sheet|
      sheet.add_row(["Annual", "Monthly", "Rate", "Cumulative"], style: header_style)
      sheet.add_row(["0", "0", "0%", "0"])
      sheet.add_row(["100,000", "8,333", "15%", "15% on next 20,000"])
      sheet.add_row(["120,000", "10,000", "30%", "30% on next 1,580,000"])
      sheet.add_row(["1,700,000", "141,667", "35%", "35% on excess above 1,700,000"])
      sheet.column_widths(18, 18, 12, 32)
      sheet.freeze_panes = "A2"
      sheet.auto_filter = "A1:D1"
    end

    package.workbook.add_worksheet(name: "Instructions") do |sheet|
      sheet.add_row(["Instructions"], style: header_style)
      sheet.add_row(["Fill all required fields marked with *. Use the drop-down lists for Payment Method, Employment Status, Medical Grade, Y/N fields and Mobile Money Provider."])
      sheet.add_row(["Choose Payment Method as bank, mobile_money, or cash. If using bank, fill Bank Name, Branch, Account Number and Account Type."])
      sheet.add_row(["If using mobile money, enter the Mobile Money Number and select a provider."])
      sheet.add_row(["Enter medical grade values as Grade A, Grade B, Grade C, or None."])
      sheet.add_row(["Use Y or N for Has Medical, Pension Exempt and Funeral Cover fields."])
      sheet.add_row(["Advance should be entered as a whole amount in MWK."])
      sheet.add_row(["This template is Malawi standard and includes PAYE bracket guidance and allowance/deduction notes."])
      sheet.column_widths(120)
      sheet.sheet_view.pane do |pane|
        pane.top_left_cell = "A2"
        pane.state = :frozen_split
        pane.y_split = 1
      end
    end

    send_data package.to_stream.read,
              filename: "PayslipPro_Standard_Template_v1_Malawi.xlsx",
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
      "S No*",
      "First Name*",
      "Last Name*",
      "Employee Code*",
      "National ID",
      "Phone Number*",
      "Email",
      "Department*",
      "Job Title*",
      "Hire Date*",
      "Employment Status*",
      "Basic Salary (MWK)*",
      "House Allowance %",
      "Other Allowances (MWK)",
      "Payment Method*",
      "Bank Name",
      "Bank Branch",
      "Account Number",
      "Account Type",
      "Mobile Money Number",
      "Mobile Money Provider",
      "Medical Grade",
      "Has Medical (Y/N)",
      "Pension Exempt (Y/N)",
      "Funeral Cover (Y/N)",
      "Advance (MWK)",
      "Notes"
    ]
  end

  def sample_template_rows
    [
      [1, "John", "Banda", "EMP001", "MW1234567890", "0999123456", "john.banda@example.com", "Finance", "Accountant", "2023-01-15", "Active", 750000, 10, 50000, "bank", "National Bank of Malawi", "Lilongwe Main", "1002345678", "Savings", nil, nil, "Grade B", "Y", "N", "Y", 0, "Experienced accountant"] ,
      [2, "Mary", "Phiri", "EMP002", "MW2234567890", "0888123456", "mary.phiri@example.com", "HR", "Recruiter", "2024-02-10", "Active", 520000, 10, 30000, "mobile_money", nil, nil, nil, "mobile_money", "0999988877", "Airtel Money", "Grade A", "Y", "N", "N", 0, "Mobile money salary"] ,
      [3, "Grace", "Tembo", "EMP003", "MW3234567890", "0877123456", "grace.tembo@example.com", "Procurement", "Supervisor", "2024-05-20", "On Leave", 420000, 10, 20000, "cash", nil, nil, nil, nil, nil, nil, "Grade C", "N", "N", "Y", 15000, "Cash paid worker"] ,
      [4, "Peter", "Mwale", "EMP004", "MW4234567890", "0999123987", "peter.mwale@example.com", "Operations", "Supervisor", "2023-11-30", "Active", 620000, 10, 40000, "bank", "Standard Bank", "Blantyre Branch", "2009876543", "Checking", nil, nil, "Grade B", "Y", "N", "Y", 0, "Bank payout"] ,
      [5, "Esther", "Kumwenda", "EMP005", "MW5234567890", "0888123987", "esther.kumwenda@example.com", "Sales", "Sales Representative", "2024-03-01", "Blocked", 390000, 10, 15000, "mobile_money", nil, nil, nil, "0999366788", "TNM Mpamba", "Grade A", "Y", "Y", "N", 5000, "Blocked employee example"]
    ]
  end
end
