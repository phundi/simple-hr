# frozen_string_literal: true

require_relative 'malawi_paye_calculator'

class PayrollComputationService
  def initialize(employee, pay_period, payroll_settings, advances = [], employee_components = [])
    @employee = employee
    @pay_period = pay_period
    @settings = payroll_settings
    @advances = advances || []
    @employee_components = employee_components || []
  end

  def call
    basic = (@employee.respond_to?(:salary) ? BigDecimal(@employee.salary.to_s) : BigDecimal('0'))

    allowances = compute_allowances(basic)
    gross = basic + allowances.values.sum

    pension_employee = (gross * (BigDecimal(@settings[:pension_employee_rate].to_s) rescue BigDecimal('0.05'))).round(2)
    taxable_income = (gross - pension_employee).round(2)

    paye = BigDecimal(MalawiPayeCalculator.new(taxable_income, @settings[:paye_brackets]).call.to_s)

    advances_total = @advances.sum { |a| a.respond_to?(:amount) ? BigDecimal(a.amount.to_s) : BigDecimal(a.to_s) }

    deductions_breakdown = {
      paye: paye.round(2),
      pension_employee: pension_employee.round(2),
      advances: advances_total.round(2)
    }

    employer_benefits = compute_employer_benefits(basic)
    total_employer_benefits = employer_benefits.values.sum.round(2)

    total_deductions = (paye + pension_employee + advances_total).round(2)
    net_pay = (gross - total_deductions).round(2)
    total_remuneration = (gross + total_employer_benefits).round(2)

    {
      basic_salary: basic.round(2),
      allowances: allowances.transform_values { |v| BigDecimal(v.to_s).round(2) },
      gross_income: gross.round(2),
      employer_benefits: employer_benefits.transform_values { |v| BigDecimal(v.to_s).round(2) },
      total_employer_benefits: total_employer_benefits,
      total_remuneration: total_remuneration,
      deductions_breakdown: deductions_breakdown,
      total_deductions: total_deductions,
      net_pay: net_pay,
      taxable_income: taxable_income.round(2)
    }
  end

  private

  def compute_allowances(basic)
    result = {}

    # House allowance (company default unless overridden by employee components)
    house_rate = @settings[:house_allowance_rate] || 0.1
    house_enabled = true

    # Check if employee has a component overriding house allowance
    @employee_components.each do |ec|
      pc = ec.respond_to?(:payroll_component) ? ec.payroll_component : nil
      next unless pc

      next unless pc.code.to_s.downcase.include?('house')

      next unless ec.respond_to?(:enabled) ? ec.enabled : true

      if ec.respond_to?(:custom_rate) && ec.custom_rate
        house_rate = ec.custom_rate.to_f
      elsif pc.default_rate
        house_rate = pc.default_rate.to_f
      end
    end

    result[:house_allowance] = (basic * BigDecimal(house_rate.to_s)).round(2) if house_enabled

    # Other components marked as allowance
    @employee_components.each do |ec|
      pc = ec.respond_to?(:payroll_component) ? ec.payroll_component : nil
      next unless pc
      next unless pc.category.to_s == 'allowance'
      next unless ec.respond_to?(:enabled) ? ec.enabled : true

      value = if ec.respond_to?(:custom_amount) && ec.custom_amount
                BigDecimal(ec.custom_amount.to_s)
              elsif ec.respond_to?(:custom_rate) && ec.custom_rate
                (basic * BigDecimal(ec.custom_rate.to_s))
              elsif pc.calculation_type == 'fixed' && pc.default_amount
                BigDecimal(pc.default_amount.to_s)
              elsif pc.calculation_type == 'percent_basic' && pc.default_rate
                basic * BigDecimal(pc.default_rate.to_s)
              else
                BigDecimal('0')
              end

      result[pc.code.to_sym] = value.round(2)
    end

    result
  end

  def compute_employer_benefits(basic)
    eb = {}
    settings = @settings

    eb[:pension_employer] = (basic * BigDecimal((settings[:pension_employer_rate] || 0.10).to_s)).round(2)
    eb[:funeral] = (basic * BigDecimal((settings[:funeral_rate] || 0.01).to_s)).round(2)
    eb[:tevet] = (basic * BigDecimal((settings[:tevet_rate] || 0.01).to_s)).round(2)
    eb[:life_assurance] = (basic * BigDecimal((settings[:life_assurance_rate] || 0.01).to_s)).round(2)

    # Pension admin and VAT
    admin = (basic * BigDecimal((settings[:pension_admin_rate] || 0.003).to_s)).round(2)
    vat = (admin * BigDecimal((settings[:admin_vat_rate] || 0.165).to_s)).round(2)
    eb[:pension_admin] = admin
    eb[:pension_admin_vat] = vat

    # Medical may be a fixed value per grade provided in settings
    if settings[:medical_grades].is_a?(Hash)
      grade = @employee.respond_to?(:medical_grade) ? @employee.medical_grade : nil
      eb[:medical] = settings[:medical_grades][grade.to_s] if grade && settings[:medical_grades][grade.to_s]
    end

    eb.transform_values { |v| (v || 0.0).round(2) }
  end
end
