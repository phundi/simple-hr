class CompanyConfig < ApplicationRecord
  belongs_to :company

  validates :key, presence: true, uniqueness: { scope: :company_id, case_sensitive: false }
end
