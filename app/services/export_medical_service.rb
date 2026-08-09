class ExportMedicalService
  def initialize(company:, pay_period:)
    @company = company
    @pay_period = pay_period
  end

  def call
    package = Axlsx::Package.new
    workbook = package.workbook

    workbook.add_worksheet(name: "Medical") do |sheet|
      sheet.add_row ["S No", "Name", "Gross Income", "Medical"]

      total_medical = 0.0

      @pay_period.payslips.includes(:employee).find_each.with_index(1) do |ps, idx|
        name = ps.employee&.full_name
        medical = (ps.employer_benefits || {})['medical'] || (ps.employer_benefits || {})[:medical] || 0
        total_medical += medical.to_f
        sheet.add_row [idx, name, ps.gross.to_f, medical]
      end

      sheet.add_row []
      sheet.add_row ["", "Total", "", total_medical]
    end

    package.to_stream.read
  end
end
