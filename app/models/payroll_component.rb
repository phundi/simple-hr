# frozen_string_literal: true

class PayrollComponent < ApplicationRecord
  belongs_to :company
  has_many :employee_payroll_components, dependent: :destroy

  CATEGORIES = %w[allowance deduction employer_benefit statutory].freeze
  CALCULATION_TYPES = %w[fixed percent_basic percent_gross percent_gross_taxable fixed_by_grade].freeze

  validates :name, :code, :category, :calculation_type, presence: true
  validates :category, inclusion: { in: CATEGORIES }
  validates :calculation_type, inclusion: { in: CALCULATION_TYPES }
  validates :code, uniqueness: { scope: :company_id }
  validate :percent_rate_within_bounds

  private

  def percent_rate_within_bounds
    if calculation_type.to_s.start_with?('percent') && default_rate.present?
      unless default_rate >= 0 && default_rate <= 1
        errors.add(:default_rate, 'must be between 0 and 1 for percent-based components')
      end
    end
  end
end
