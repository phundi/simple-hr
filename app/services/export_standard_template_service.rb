# frozen_string_literal: true

require 'axlsx'
require 'tempfile'

class ExportStandardTemplateService
  def initialize(company)
    @company = company
  end

  # Generates an Excel workbook with two sheets:
  #  - "Employees" with headers and example rows
  #  - "Company Rates" with default Malawi payroll settings and PAYE brackets
  # Returns the path to a temporary .xlsx file containing the template.
  def call
    pkg = Axlsx::Package.new
    wb = pkg.workbook

    header_style = wb.styles.add_style(bg_color: '206bc4', fg_color: 'FFFFFF', b: true)

    wb.add_worksheet(name: 'Employees') do |sheet|
      headers = [
        'Employee Code*',
        'First Name*',
        'Last Name*',
        'Gender (Male/Female)',
        'Position',
        'Department',
        'Project/Donor',
        'Supervisor',
        'Nationality',
        'Location',
        'Basic Salary* (MWK)',
        'House Allowance % (default 10%)',
        'Other Allowances',
        'Payment Method (bank/mobile_money/cash)',
        'Bank Name',
        'Bank Account Number',
        'Mobile Money Number',
        'Mobile Money Provider (airtel/tigo)',
        'Medical Grade (A/B)',
        'Salary Advance (optional)'
      ]

      sheet.add_row headers, style: header_style

      # Example rows (values inspired by the Malawi sample)
      sheet.add_row [
        'E001',
        'John',
        'Banda',
        'Male',
        'Accountant',
        'Finance',
        'Project Alpha',
        'Supervisor A',
        'Malawian',
        'Lilongwe',
        3_051_000,
        0.10,
        50_000,
        'bank',
        'NBS',
        '1234567890',
        '',
        '',
        'A',
        0
      ]

      sheet.add_row [
        'E002',
        'Jane',
        'Phiri',
        'Female',
        'HR Manager',
        'HR',
        'Project Beta',
        'Supervisor B',
        'Malawian',
        'Blantyre',
        1_886_230,
        0.10,
        20_000,
        'mobile_money',
        '',
        '',
        '0999988888',
        'airtel',
        'B',
        0
      ]

      # Add data validation for Gender and Payment Method columns
      # Gender column: D (4th column) => D2:D1000
      sheet.add_data_validation('D2:D1000', {
        type: :list,
        formula1: '"Male,Female"',
        allow_blank: true,
        showDropDown: true
      })

      # Payment Method column: N (14th column) => N2:N1000
      sheet.add_data_validation('N2:N1000', {
        type: :list,
        formula1: '"bank,mobile_money,cash"',
        allow_blank: true,
        showDropDown: true
      })

      # Freeze the header row
      sheet.sheet_view.pane = Axlsx::Pane.new(top_left_cell: 'A2', y_split: 1, active_pane: :bottomLeft, state: :frozen)
      sheet.auto_filter = "A1:T1"
      # Set some column widths to make the template readable
      sheet.column_widths 15, 12, 12, 10, 18, 16, 18, 16, 14, 14, 14, 10, 14, 18, 14, 18, 16, 20, 8, 14
    end

    wb.add_worksheet(name: 'Company Rates') do |sheet|
      sheet.add_row ['Setting', 'Value'], style: header_style

      rates = [
        ['Pension Employer (%)', 0.10],
        ['Pension Employee (%)', 0.05],
        ['Funeral (%)', 0.01],
        ['Tevet (%)', 0.01],
        ['Life Assurance (%)', 0.01],
        ['Pension Admin (%)', 0.003],
        ['Admin VAT (%)', 0.165],
        ['House Allowance (%)', 0.10]
      ]

      rates.each { |r| sheet.add_row r }

      sheet.add_row []
      sheet.add_row ['PAYE Bracket Limit', 'Rate'], style: header_style
      sheet.add_row [170_000, 0.0]
      sheet.add_row [420_000, 0.3]
      sheet.add_row [2_950_000, 0.35]
      sheet.add_row ['Above', 0.4]

      sheet.sheet_view.pane = Axlsx::Pane.new(top_left_cell: 'A2', y_split: 1, active_pane: :bottomLeft, state: :frozen)
      sheet.column_widths 30, 14
    end

    tmp = Tempfile.new(['payslip_pro_template', '.xlsx'])
    tmp.binmode
    pkg.serialize(tmp.path)
    tmp.close
    tmp.path
  end
end
