class CompanyProperty < ApplicationRecord
  belongs_to :company

  PROPERTY_KEYS = %w[department employee_role payment_method].freeze

  validates :property_key, presence: true, inclusion: { in: PROPERTY_KEYS }
  validates :value, presence: true, uniqueness: { scope: [ :company_id, :property_key ], case_sensitive: false }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  before_validation :normalize_value

  private

  def normalize_value
    self.value = value.to_s.strip
  end
end
