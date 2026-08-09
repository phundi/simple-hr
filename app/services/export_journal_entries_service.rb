class ExportJournalEntriesService
  def initialize(company:, pay_period:)
    @company = company
    @pay_period = pay_period
  end

  def call
    total_gross = 0.0
    total_employer_benefits = 0.0
    total_paye = 0.0
    total_pension_employee = 0.0
    total_net = 0.0

    @pay_period.payslips.includes(:employee).find_each do |ps|
      total_gross += ps.gross.to_f
      eb = ps.respond_to?(:employer_benefits) ? (ps.employer_benefits || {}) : {}
      total_employer_benefits += (eb.values.sum rescue 0)
      total_paye += (ps.respond_to?(:paye) ? ps.paye.to_f : (ps.deductions_breakdown || {})['paye'].to_f)
      total_pension_employee += (ps.respond_to?(:pension_employee) ? ps.pension_employee.to_f : (ps.deductions_breakdown || {})['pension_employee'].to_f)
      total_net += ps.net.to_f
    end

    package = Axlsx::Package.new
    workbook = package.workbook

    workbook.add_worksheet(name: "Journal Entries") do |sheet|
      sheet.add_row ["Account", "Debit", "Credit"]
      # Debit Salary Expense
      sheet.add_row ["Salary Expense", total_gross, ""]
      # Debit Employer Benefits
      sheet.add_row ["Employer Benefits Expense", total_employer_benefits, ""]
      sheet.add_row []
      # Credit PAYE Payable
      sheet.add_row ["PAYE Payable", "", total_paye]
      # Credit Pension Payable (employee portion)
      sheet.add_row ["Pension Payable", "", total_pension_employee]
      # Credit Bank/Cash (net pay)
      sheet.add_row ["Bank/Cash", "", total_net]
    end

    package.to_stream.read
  end
end
