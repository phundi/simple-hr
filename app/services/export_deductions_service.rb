class ExportDeductionsService
  def initialize(company:, pay_period:)
    @company = company
    @pay_period = pay_period
  end

  def call
    package = Axlsx::Package.new
    workbook = package.workbook

    workbook.add_worksheet(name: "Deductions") do |sheet|
      sheet.add_row ["S No", "Name", "Advance", "PAYE", "Pension Employee", "Other Deductions", "Total Deductions"]

      total_cols = Array.new(4, 0.0)

      @pay_period.payslips.includes(:employee).find_each.with_index(1) do |ps, idx|
        advances = (ps.deductions_breakdown || {})['advances'] || 0
        paye = (ps.deductions_breakdown || {})['paye'] || 0
        pen_emp = (ps.deductions_breakdown || {})['pension_employee'] || 0
        other = ((ps.deductions || 0) - (advances.to_f + paye.to_f + pen_emp.to_f)).to_f
        total = advances.to_f + paye.to_f + pen_emp.to_f + other

        total_cols[0] += advances.to_f
        total_cols[1] += paye.to_f
        total_cols[2] += pen_emp.to_f
        total_cols[3] += total

        sheet.add_row [idx, ps.employee&.full_name, advances, paye, pen_emp, other, total]
      end

      sheet.add_row []
      sheet.add_row ["", "Total", *total_cols]
    end

    package.to_stream.read
  end
end
