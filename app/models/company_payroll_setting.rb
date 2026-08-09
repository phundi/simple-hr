# frozen_string_literal: true

class CompanyPayrollSetting < ApplicationRecord
  belongs_to :company

  DEFAULT_BRACKETS = [
    { "min" => 0, "max" => 100_000, "rate" => 0 },
    { "min" => 100_001, "max" => 120_000, "rate" => 15 },
    { "min" => 120_001, "max" => 1_700_000, "rate" => 30 },
    { "min" => 1_700_001, "max" => 9_999_999_999, "rate" => 35 }
  ].freeze

  attribute :paye_brackets, :json, default: DEFAULT_BRACKETS
  attribute :medical_grades, :json, default: {}
  attribute :house_allowance_auto, :boolean, default: true

  validates :company_id, uniqueness: true
  validates :tax_year, presence: true
  validates :tax_free_threshold, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :house_allowance_rate, :pension_employer_rate, :pension_employee_rate, :funeral_rate, :tevet_rate, :life_assurance_rate, :pension_admin_rate, :admin_vat_rate, numericality: { greater_than_or_equal_to: 0 }
end
