class PayrollProcessingService
  def initialize(user:, company:, pay_period: nil)
    @user = user
    @company = company
    @pay_period = pay_period
  end

  def call
    raise "Unauthorized" unless user&.can?("process_payroll")

    # TODO: implement payroll processing workflow.
    true
  end

  private

  attr_reader :user, :company, :pay_period
end
