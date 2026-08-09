class ExportFuneralService
  def initialize(company:, pay_period:)
    @company = company
    @pay_period = pay_period
  end

  def call
    package = Axlsx::Package.new
    workbook = package.workbook

    workbook.add_worksheet(name: "Funeral Cover") do |sheet|
      sheet.add_row ["S No", "Name", "Gross Income", "Funeral"]

      total_gross = 0.0
      total_funeral = 0.0

      @pay_period.payslips.includes(:employee).find_each.with_index(1) do |ps, idx|
        name = ps.employee&.full_name
        gross = ps.gross.to_f
        funeral = (ps.employer_benefits || {})['funeral'] || (ps.employer_benefits || {})[:funeral] || 0
        total_gross += gross
        total_funeral += funeral.to_f
        sheet.add_row [idx, name, gross, funeral]
      end

      sheet.add_row []
      sheet.add_row ["", "Total", total_gross, total_funeral]
    end

    package.to_stream.read
  end
end
