class Payslip < ApplicationRecord
  belongs_to :pay_period
  belongs_to :employee

  has_one :company, through: :pay_period

  def footer_text
    ConfigService.get(nil, company, "payslip_footer_text") || "This is a computer generated payslip"
  end
end
