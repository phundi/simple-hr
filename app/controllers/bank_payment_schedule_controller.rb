class BankPaymentScheduleController < ApplicationController
  def export
    pay_period = selected_pay_period
    xlsx_data = generate_xlsx(pay_period)

    send_data xlsx_data,
              type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
              filename: export_filename(pay_period)
  end

  private

  def selected_pay_period
    if params[:pay_period_id].present?
      current_company.pay_periods.find_by(id: params[:pay_period_id])
    else
      current_company.pay_periods.published.order(year: :desc, month: :desc).first ||
        current_company.pay_periods.order(year: :desc, month: :desc).first
    end
  end

  def generate_xlsx(pay_period)
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

  def export_filename(pay_period)
    suffix = if pay_period
      format("%<year>d-%<month>02d", year: pay_period.year, month: pay_period.month)
    else
      Date.current.strftime("%Y-%m")
    end

    "bank_payment_schedule_#{suffix}.xlsx"
  end
end
