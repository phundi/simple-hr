class ExportPayeService
  def initialize(user:, company:, pay_period: nil)
    @user = user
    @company = company
    @pay_period = pay_period
  end

  def call
    raise "Unauthorized" unless user&.can?("export_paye_schedule")

    # TODO: implement PAYE export format when PAYE report flow is introduced.
    true
  end

  private

  attr_reader :user, :company, :pay_period
end
