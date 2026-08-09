# frozen_string_literal: true

require 'prawn'
require 'prawn/table'

class GeneratePayslipPdfService
  def initialize(payslip)
    @payslip = payslip
    @company = payslip.company
    @employee = payslip.employee
  end

  def call
    Prawn::Document.new(page_size: 'A4', margin: 36) do |pdf|
      header(pdf)
      pdf.stroke_horizontal_rule
      pdf.move_down 8
      employee_grid(pdf)
      pdf.move_down 8
      income_and_deductions(pdf)
      pdf.move_down 8
      other_benefits(pdf)
      pdf.move_down 16
      footer_totals(pdf)
    end.render
  end

  private

  def header(pdf)
    if @company.logo.attached? rescue false
      begin
        logo = StringIO.new(@company.logo.download)
        pdf.image logo, width: 80, at: [pdf.bounds.left, pdf.cursor]
      rescue StandardError
        # ignore logo errors
      end
    end

    pdf.move_down 10
    pdf.font_size 14
    pdf.text_box @company.name, at: [120, pdf.cursor + 40], size: 16, style: :bold
    pdf.move_down 24
    pdf.text "PAYSLIP FOR THE MONTH OF #{Date::MONTHNAMES[@payslip.pay_period.month]} #{@payslip.pay_period.year}", size: 12, style: :bold, align: :center
  end

  def employee_grid(pdf)
    data = [
      ["Employee", @employee.full_name.to_s, "Position", @employee.job_title.to_s],
      ["Employee Code", @employee.employee_code.to_s, "Project/Dept", @employee.department.to_s],
      ["Date", @payslip.pay_period.month.to_s + "/" + @payslip.pay_period.year.to_s, "Location", @employee.location.to_s],
      ["Grade", @employee.respond_to?(:medical_grade) ? @employee.medical_grade.to_s : '', "Supervisor", @employee.supervisor.to_s]
    ]

    pdf.table(data, cell_style: { borders: [] }, column_widths: [90, 200, 90, 150])
  end

  def income_and_deductions(pdf)
    income = [
      ["Basic Salary", money(@payslip.basic_salary)],
    ]

    (@payslip.allowances || {}).each do |k, v|
      income << [k.to_s.humanize, money(v)]
    end
    income << ["Gross Income", money(@payslip.gross || @payslip.basic_salary + (@payslip.allowances || {}).values.sum)]

    deductions = []
    deductions << ["PAYE", money(@payslip.paye || (@payslip.deductions_breakdown || {})['paye'])]
    deductions << ["Pension Employee", money(@payslip.pension_employee || (@payslip.deductions_breakdown || {})['pension_employee'])]
    deductions << ["Salary Advance", money((@payslip.deductions_breakdown || {})['advances'] || 0)]
    deductions << ["Total Deductions", money(@payslip.net ? (@payslip.gross - @payslip.net) : deductions.map { |d| d[1].to_f }.sum)]

    pdf.table([["INCOME", "AMOUNT", "DEDUCTIONS", "AMOUNT"]], column_widths: [180, 100, 180, 100], row_colors: [])

    rows = []
    max = [income.size, deductions.size].max
    max.times do |i|
      rows << [income[i] ? income[i][0] : '', income[i] ? income[i][1] : '', deductions[i] ? deductions[i][0] : '', deductions[i] ? deductions[i][1] : '']
    end

    pdf.table(rows, column_widths: [180, 100, 180, 100], cell_style: { borders: [] })
  end

  def other_benefits(pdf)
    pdf.text "Other Benefits", style: :bold
    data = []
    (@payslip.employer_benefits || {}).each do |k, v|
      data << [k.to_s.humanize, money(v)]
    end
    data << ["Total Benefits", money(@payslip.total_employer_benefits || (@payslip.employer_benefits || {}).values.sum)]
    pdf.table(data, column_widths: [300, 120], cell_style: { borders: [] })
  end

  def footer_totals(pdf)
    total_rem = @payslip.total_remuneration || (@payslip.gross.to_f + (@payslip.total_employer_benefits || 0).to_f)
    net = @payslip.net || (@payslip.gross.to_f - ((@payslip.deductions_breakdown || {})['paye'].to_f + (@payslip.deductions_breakdown || {})['pension_employee'].to_f + ((@payslip.deductions_breakdown || {})['advances'] || 0).to_f))

    pdf.move_down 8
    pdf.text "Total Remuneration: #{money(total_rem)}", style: :bold
    pdf.text "NET SALARY: #{money(net)}", size: 14, style: :bold
    pdf.move_down 12
    pdf.text @payslip.footer_text

    pdf.move_down 24
    pdf.text "__________________________", align: :left
    pdf.text "Manager Signature", align: :left
  end

  def money(amount)
    return "" if amount.nil?
    sprintf("%0.2f", amount.to_f)
  end
end
