class ExportTevetService
  def initialize(company:, pay_period:)
    @company = company
    @pay_period = pay_period
  end

  def call
    package = Axlsx::Package.new
    workbook = package.workbook

    workbook.add_worksheet(name: "Tevet Levy") do |sheet|
      sheet.add_row ["S No", "Name", "Gross Income", "Tevet Levy"]

      total_gross = 0.0
      total_tevet = 0.0

      @pay_period.payslips.includes(:employee).find_each.with_index(1) do |ps, idx|
        name = ps.employee&.full_name
        gross = ps.gross.to_f
        tevet = (ps.employer_benefits || {})['tevet'] || (ps.employer_benefits || {})[:tevet] || 0
        total_gross += gross
        total_tevet += tevet.to_f
        sheet.add_row [idx, name, gross, tevet]
      end

      sheet.add_row []
      sheet.add_row ["", "Total", total_gross, total_tevet]
    end

    package.to_stream.read
  end
end
