# frozen_string_literal: true

require 'test_helper'
require_relative '../../app/services/malawi_paye_calculator'

class MalawiPayeCalculatorTest < ActiveSupport::TestCase
  test 'paye is zero for zero taxable' do
    calc = MalawiPayeCalculator.new(0)
    assert_equal 0.0, calc.call
  end

  test 'paye for sample taxable income matches bracket calculation' do
    taxable = 3_188_295.0
    calc = MalawiPayeCalculator.new(taxable)

    # manual calculation using the default brackets
    remaining = taxable
    expected = 0.0
    brackets = MalawiPayeCalculator::DEFAULT_BRACKETS
    brackets.each do |b|
      break if remaining <= 0
      if b[:limit].finite?
        taxable_in_bracket = [remaining, b[:limit]].min
        expected += taxable_in_bracket * b[:rate]
        remaining -= taxable_in_bracket
      else
        expected += remaining * b[:rate]
        remaining = 0
      end
    end

    assert_in_delta expected.round(2), calc.call, 0.01
  end
end
