# frozen_string_literal: true

class MalawiPayeCalculator
  DEFAULT_BRACKETS = [
    { limit: 170_000, rate: 0.0 },
    { limit: 420_000, rate: 0.3 },
    { limit: 2_950_000, rate: 0.35 },
    { limit: Float::INFINITY, rate: 0.4 }
  ].freeze

  def initialize(taxable_income, brackets = nil)
    @taxable_income = taxable_income.to_d
    @brackets = brackets || DEFAULT_BRACKETS
  end

  def call
    remaining = @taxable_income
    paye = 0.to_d

    @brackets.each do |b|
      break if remaining <= 0.to_d

      limit = BigDecimal(b[:limit].to_s) rescue b[:limit]
      rate = BigDecimal(b[:rate].to_s)

      if limit.respond_to?(:finite?) && limit.finite?
        taxable_in_bracket = [remaining, BigDecimal(limit.to_s)].min
        paye += taxable_in_bracket * rate
        remaining -= taxable_in_bracket
      else
        paye += remaining * rate
        remaining = 0.to_d
      end
    end

    paye.round(2)
  end
end
