# frozen_string_literal: true

class EmployeeAdvance < ApplicationRecord
  belongs_to :employee
  belongs_to :company

  STATUSES = %w[active repaid cancelled].freeze

  validates :amount, :balance, presence: true
  validates :status, inclusion: { in: STATUSES }
end
