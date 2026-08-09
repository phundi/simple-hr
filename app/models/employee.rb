class Employee < ApplicationRecord
  belongs_to :company
  belongs_to :user, optional: true
  belongs_to :import_template, optional: true
  has_many :payslips, dependent: :destroy
  has_many :employee_payroll_components, dependent: :destroy
  has_many :employee_advances, dependent: :destroy

  validates :employee_code, uniqueness: { scope: :company_id }
  validates :payment_method, presence: true
  validates :bank_name, :bank_account_number, presence: true, if: :payment_method_bank?
  validates :bank_name, presence: { message: 'is required when Payment Method is Bank' }, if: :payment_method_bank?
  validates :bank_account_number, presence: { message: 'is required when Payment Method is Bank' }, if: :payment_method_bank?
  validates :mobile_money_number, presence: true, if: :payment_method_mobile_money?
  validates :salary, numericality: { greater_than: 0 }, if: -> { salary.present? }

  enum :employment_status, { active: 0, blocked: 1, terminated: 2, on_leave: 3 }, default: :active, prefix: true
  enum :onboarding_status, { unverified: 0, verified: 1 }, default: :unverified, prefix: true
  enum :account_type, { savings: 0, checking: 1 }, prefix: true
  enum :mobile_money_provider, { airtel: 0, tigo: 1 }, prefix: true
  enum :payment_method, { bank: 0, mobile_money: 1, cash: 2 }, prefix: true

  delegate :email, to: :user, prefix: true, allow_nil: true

  def full_name
    [first_name, last_name].compact.join(' ').strip.presence || employee_code.to_s.presence || 'Employee'
  end

  scope :payroll_eligible, lambda {
    left_joins(:user)
      .where(employment_status: employment_statuses[:active], onboarding_status: onboarding_statuses[:verified])
      .where("users.id IS NULL OR users.status = ?", User.statuses[:active])
  }

  def block!
    update!(employment_status: :blocked)
  end

  def unblock!
    update!(employment_status: :active)
  end

  private

  def payment_method_bank?
    payment_method == "bank"
  end

  def payment_method_mobile_money?
    payment_method == "mobile_money"
  end
end
