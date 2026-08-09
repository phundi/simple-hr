class PayslipsController < ApplicationController
  before_action :authenticate_user!
  before_action -> { authorize!("view_payroll") }, only: [:pdf, :email]

  def pdf
    payslip = current_company.payslips.find(params[:id])
    pdf = GeneratePayslipPdfService.new(payslip).call
    send_data pdf, filename: "payslip_#{payslip.id}.pdf", type: 'application/pdf', disposition: 'inline'
  end

  def email
    payslip = current_company.payslips.find(params[:id])
    EmployeeMailer.with(company: current_company).payslip(payslip.id).deliver_later
    redirect_back fallback_location: employee_payroll_path(payslip.employee), notice: 'Payslip emailed.'
  end

  def update
    payslip = current_company.payslips.find(params[:id])
    authorize!("edit_payroll")

    basic = params[:basic_salary].presence || payslip.basic_salary
    allowances = params[:allowances].presence
    advances = params[:advance].presence

    # Build a temporary employee struct for recomputation
    employee_struct = Struct.new(:salary, :medical_grade).new(basic.to_f, nil)
    settings = current_company.company_payroll_setting || {}
    computation = PayrollComputationService.new(employee_struct, payslip.pay_period, {
      house_allowance_rate: settings.try(:house_allowance_rate) || 0.1,
      pension_employee_rate: settings.try(:pension_employee_rate) || 0.05,
      pension_employer_rate: settings.try(:pension_employer_rate) || 0.1,
      paye_brackets: settings.try(:paye_brackets) || MalawiPayeCalculator::DEFAULT_BRACKETS,
      medical_grades: settings.try(:medical_grades) || {}
    }, payslip.employee.employee_advances, [])

    result = computation.call

    payslip.basic_salary = result[:basic_salary]
    payslip.gross = result[:gross_income]
    payslip.employer_benefits = result[:employer_benefits]
    payslip.total_employer_benefits = result[:total_employer_benefits]
    payslip.total_remuneration = result[:total_remuneration]
    payslip.deductions_breakdown = result[:deductions_breakdown]
    payslip.total_deductions = result[:total_deductions]
    payslip.net = result[:net_pay]
    payslip.taxable_income = result[:taxable_income]

    if payslip.save
      render partial: 'pay_periods/row', locals: { payslip: payslip }
    else
      head :unprocessable_entity
    end
  end
end
