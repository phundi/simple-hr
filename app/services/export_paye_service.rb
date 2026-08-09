class ExportPayeService
  def initialize(company:, pay_period:)
    @company = company
    @pay_period = pay_period
  end

  def call
    package = Axlsx::Package.new
    workbook = package.workbook

    workbook.add_worksheet(name: "PAYE List") do |sheet|
      sheet.add_row ["S No", "Name", "Gross Income", "PAYE Deduction"]

      total_gross = 0.0
      total_paye = 0.0

      @pay_period.payslips.includes(:employee).find_each.with_index(1) do |ps, idx|
        name = ps.employee&.full_name
        gross = ps.gross.to_f
        paye = (ps.respond_to?(:paye) ? ps.paye.to_f : (ps.deductions_breakdown || {})['paye'].to_f)
        total_gross += gross
        total_paye += paye

        sheet.add_row [idx, name, gross, paye]
      end

      sheet.add_row []
      sheet.add_row ["", "Total", total_gross, total_paye]
    end

    package.to_stream.read
  end
end
class ExportPayeService
  def initialize(user:, company:, pay_period: nil)
    @user = user
    @company = company
    @pay_period = pay_period
  end

  def call
    raise "Unauthorized" unless user&.can?("export_paye_schedule")

    # TODO: implement PAYE export format when PAYE report flow is introduced.
    true
  end

  private

  attr_reader :user, :company, :pay_period
end
