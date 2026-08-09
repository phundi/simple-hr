# frozen_string_literal: true

class EmployeePayrollsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_employee
  before_action -> { authorize!("view_payroll") }

  def show
    @tabs = %w[general allowances deductions benefits payslip]
    @current_tab = params[:tab].presence_in(@tabs) || 'general'

    @pay_periods = current_company.pay_periods.order(year: :desc, month: :desc)
    @pay_period = if params[:pay_period_id].present?
      @pay_periods.find_by(id: params[:pay_period_id])
    else
      @pay_periods.first
    end

    @month = @pay_period&.month || Date.current.month
    @year = @pay_period&.year || Date.current.year
    @payslip = @pay_period&.payslips&.find_by(employee: @employee)

    settings = current_company.company_payroll_setting
    default_settings = {
      house_allowance_rate: 0.10,
      pension_employee_rate: 0.05,
      pension_employer_rate: 0.10,
      funeral_rate: 0.01,
      tevet_rate: 0.01,
      life_assurance_rate: 0.01,
      pension_admin_rate: 0.003,
      admin_vat_rate: 0.165,
      paye_brackets: MalawiPayeCalculator::DEFAULT_BRACKETS,
      medical_grades: {}
    }

    settings_hash = {
      tax_year: settings.respond_to?(:tax_year) ? settings.tax_year : Date.current.year.to_s,
      tax_free_threshold: settings.respond_to?(:tax_free_threshold) ? settings.tax_free_threshold : 100_000,
      house_allowance_auto: settings.respond_to?(:house_allowance_auto) ? settings.house_allowance_auto : true,
      house_allowance_rate: settings&.house_allowance_rate || default_settings[:house_allowance_rate],
      pension_employee_rate: settings&.pension_employee_rate || default_settings[:pension_employee_rate],
      pension_employer_rate: settings&.pension_employer_rate || default_settings[:pension_employer_rate],
      funeral_rate: settings&.funeral_rate || default_settings[:funeral_rate],
      tevet_rate: settings&.tevet_rate || default_settings[:tevet_rate],
      life_assurance_rate: settings&.life_assurance_rate || default_settings[:life_assurance_rate],
      pension_admin_rate: settings&.pension_admin_rate || default_settings[:pension_admin_rate],
      admin_vat_rate: settings&.admin_vat_rate || default_settings[:admin_vat_rate],
      paye_brackets: settings&.paye_brackets || default_settings[:paye_brackets],
      medical_grades: settings&.medical_grades || default_settings[:medical_grades]
    }

    employee_struct = Struct.new(:salary, :medical_grade).new(@employee.salary.to_f, @employee.respond_to?(:medical_grade) ? @employee.medical_grade : nil)

    @computation = PayrollComputationService.new(employee_struct, @pay_period || PayPeriod.new(month: Date.current.month, year: Date.current.year), settings_hash, @employee.employee_advances, @employee.employee_payroll_components).call

    @tax_year = settings_hash[:tax_year]
    @paye_brackets = settings_hash[:paye_brackets]
    @basic = @employee.salary.to_f
    @allowances_total = @computation[:allowances].values.sum
    @gross = @computation[:gross_income]
    @pension_employee = @computation[:deductions_breakdown][:pension_employee]
    @paye = @computation[:deductions_breakdown][:paye]
    @advances = @employee.employee_advances.order(issue_date: :desc)
    @net_pay = @computation[:net_pay]
    @employer_benefits_total = @computation[:total_employer_benefits]

    allowances = @computation[:allowances] || {}
    @allowance_items = [
      { name: 'House Allowance', description: '10% of basic salary', taxable: true, amount: allowances[:house_allowance] || 0, enabled: true },
      { name: 'Transport', description: 'Fixed transport allowance', taxable: true, amount: allowances[:transport] || 0, enabled: allowances[:transport].to_f > 0 },
      { name: 'Overtime', description: 'Fixed overtime allowance', taxable: true, amount: allowances[:overtime] || 0, enabled: allowances[:overtime].to_f > 0 },
      { name: 'Responsibility', description: 'Fixed responsibility allowance', taxable: true, amount: allowances[:responsibility] || 0, enabled: allowances[:responsibility].to_f > 0 }
    ]

    benefits = @computation[:employer_benefits] || {}
    @benefit_items = [
      { name: 'Medical', label: 'Fixed', amount: benefits[:medical] || 0 },
      { name: 'Pension Employer', label: '10% Basic', amount: benefits[:pension_employer] || 0 },
      { name: 'Funeral Cover', label: '1% Basic', amount: benefits[:funeral] || 0 },
      { name: 'Tevet Levy', label: '1% Basic', amount: benefits[:tevet] || 0 },
      { name: 'Life Assurance', label: '1% Basic', amount: benefits[:life_assurance] || 0 },
      { name: 'Pension Admin', label: '0.3% Basic', amount: benefits[:pension_admin] || 0 },
      { name: 'VAT on Admin', label: '16.5% of admin', amount: benefits[:pension_admin_vat] || 0 }
    ]

    @deduction_items = [
      { name: 'PAYE', amount: @paye, details: 'Calculated from brackets' },
      { name: 'Pension Employee', amount: @pension_employee, details: '5% of gross pay' },
      { name: 'Advance', amount: @computation[:deductions_breakdown][:advances], details: 'Outstanding advances' }
    ]

    @custom_deductions = [
      { name: 'Welfare', amount: 0, enabled: false },
      { name: 'Union', amount: 0, enabled: false },
      { name: 'SACCO', amount: 0, enabled: false }
    ]
  end

  def update
    @pay_period = current_company.pay_periods.find_by(id: params[:pay_period_id])
    @payslip = @pay_period&.payslips&.find_or_initialize_by(employee: @employee)

    if @payslip && @payslip.update(payslip_params)
      redirect_to employee_payroll_path(@employee, pay_period_id: @pay_period&.id, tab: params[:tab]), notice: 'Payroll updated successfully.'
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def set_employee
    @employee = current_company.employees.find(params[:employee_id])
  end

  def payslip_params
    params.require(:payslip).permit(
      :basic_salary,
      :gross,
      :net,
      :paye,
      :pension_employee,
      :deductions,
      allowances: {},
      deductions_breakdown: {}
    )
  end
end
