class ExportPensionService
  def initialize(company:, pay_period:)
    @company = company
    @pay_period = pay_period
  end

  def call
    package = Axlsx::Package.new
    workbook = package.workbook

    workbook.add_worksheet(name: "Pension List") do |sheet|
      sheet.add_row ["S No", "Name", "Employer Pension", "Life Assurance", "Pension Admin", "Admin VAT", "Employee Contribution", "Total"]

      total_cols = Array.new(6, 0.0)

      @pay_period.payslips.includes(:employee).find_each.with_index(1) do |ps, idx|
        eb = ps.respond_to?(:employer_benefits) ? (ps.employer_benefits || {}) : {}
        emp_pen = value_for(eb, :pension_employer)
        life = value_for(eb, :life_assurance)
        admin = value_for(eb, :pension_admin)
        vat = value_for(eb, :pension_admin_vat)
        emp_cont = ps.respond_to?(:pension_employee) ? ps.pension_employee.to_f : (ps.deductions_breakdown || {})['pension_employee'].to_f
        total = emp_pen + life + admin + vat + emp_cont

        total_cols[0] += emp_pen
        total_cols[1] += life
        total_cols[2] += admin
        total_cols[3] += vat
        total_cols[4] += emp_cont
        total_cols[5] += total

        sheet.add_row [idx, ps.employee&.full_name, emp_pen, life, admin, vat, emp_cont, total]
      end

      sheet.add_row []
      sheet.add_row ["", "Total", *total_cols]
    end

    package.to_stream.read
  end

  private

  def value_for(hash, key)
    return 0.0 unless hash
    hash[key.to_s] || hash[key.to_sym] || 0.0
  end
end
