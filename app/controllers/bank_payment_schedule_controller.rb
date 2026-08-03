class BankPaymentScheduleController < ApplicationController
  # permission_key: export_bank_schedule
  before_action -> { authorize!("export_bank_schedule") }

  def export
    pay_period = selected_pay_period
    xlsx_data = ExportBankScheduleService.new(
      user: current_user,
      company: current_company,
      pay_period: pay_period
    ).call

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

  def export_filename(pay_period)
    suffix = if pay_period
      format("%<year>d-%<month>02d", year: pay_period.year, month: pay_period.month)
    else
      Date.current.strftime("%Y-%m")
    end

    "bank_payment_schedule_#{suffix}.xlsx"
  end
end
