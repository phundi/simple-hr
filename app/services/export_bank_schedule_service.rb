class ExportBankScheduleService
  def initialize(user:, company:, pay_period:)
    @user = user
    @company = company
    @pay_period = pay_period
  end

  def call
    raise "Unauthorized" unless user&.can?("export_bank_schedule")

    package = Axlsx::Package.new
    workbook = package.workbook

    workbook.add_worksheet(name: "Bank Schedule") do |sheet|
      sheet.add_row [ "Employee Code", "Name", "Bank", "Account", "Net Pay" ]

      if pay_period
        pay_period.payslips
                  .includes(:employee)
                  .where(employees: { payment_method: Employee.payment_methods[:bank] })
                  .references(:employees)
                  .find_each do |payslip|
          employee = payslip.employee
          next unless employee

          sheet.add_row [
            employee.employee_code,
            [ employee.first_name, employee.last_name ].compact.join(" ").strip,
            employee.bank_name,
            employee.bank_account_number,
            payslip.net.to_d.to_f
          ]
        end
      end
    end

    package.to_stream.read
  end

  private

  attr_reader :user, :company, :pay_period
end
