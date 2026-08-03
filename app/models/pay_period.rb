class PayPeriod < ApplicationRecord
  belongs_to :company
  has_many :payslips, dependent: :destroy

  enum :status, { draft: 0, published: 1 }, default: :draft
end
