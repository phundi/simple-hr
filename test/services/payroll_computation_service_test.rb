# frozen_string_literal: true

require 'test_helper'
require_relative '../../app/services/payroll_computation_service'

class PayrollComputationServiceTest < ActiveSupport::TestCase
  test 'computes payroll breakdown for simple employee' do
    employee = Struct.new(:salary, :medical_grade).new(3_051_000, 'A')
    pay_period = Struct.new(:id).new(1)
    settings = {
      house_allowance_rate: 0.10,
      pension_employee_rate: 0.05,
      pension_employer_rate: 0.10,
      funeral_rate: 0.01,
      tevet_rate: 0.01,
      life_assurance_rate: 0.01,
      pension_admin_rate: 0.003,
      admin_vat_rate: 0.165,
      paye_brackets: MalawiPayeCalculator::DEFAULT_BRACKETS,
      medical_grades: { 'A' => 101_250 }
    }

    service = PayrollComputationService.new(employee, pay_period, settings, [], [])
    result = service.call

    assert result[:basic_salary] == 3_051_000.0
    assert result[:allowances].key?(:house_allowance)
    assert result[:employer_benefits][:pension_employer] > 0
    assert result[:deductions_breakdown][:paye] >= 0
    assert result[:net_pay] == (result[:gross_income] - result[:total_deductions])
  end
end
