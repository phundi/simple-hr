require 'csv'

class PayPeriodsController < ApplicationController
  before_action :authenticate_user!
  before_action -> { authorize!("view_payroll") }, only: [:index, :show]
  before_action -> { authorize!("create_payroll") }, only: [:new, :create]
  before_action -> { authorize!("edit_payroll") }, only: [:edit, :update]
  before_action -> { authorize!("process_payroll") }, only: [:publish]
  before_action :set_pay_period, only: [:show, :edit, :update, :destroy, :publish, :export_bank_schedule, :export_paye, :export_pension, :export_tevet, :export_funeral, :export_medical, :export_deductions, :export_journal, :export_reports]

  def index
    @pay_periods = current_company.pay_periods.order(year: :desc, month: :desc)
  end

  def show
    @pay_period = @pay_period
    @payslips = @pay_period.payslips.includes(:employee).order('employees.last_name ASC')
    @tab = params[:tab].presence || 'overview'
  end

  def new
    @pay_period = current_company.pay_periods.new(year: Date.today.year, month: Date.today.month)
  end

  def create
    @pay_period = current_company.pay_periods.new(pay_period_params)
    if @pay_period.save
      redirect_to pay_period_path(@pay_period), notice: 'Pay period created.'
    else
      render :new
    end
  end

  def edit
    @pay_period = current_company.pay_periods.find(params[:id])
  end

  def update
    @pay_period = current_company.pay_periods.find(params[:id])
    if @pay_period.update(pay_period_params)
      redirect_to pay_period_path(@pay_period), notice: 'Pay period updated.'
    else
      render :edit
    end
  end

  def destroy
    @pay_period.destroy
    redirect_to pay_periods_path, notice: 'Pay period deleted.'
  end

  def publish
    if @pay_period.draft?
      @pay_period.update!(status: :published)
      redirect_to pay_period_path(@pay_period), notice: 'Payroll published.'
    else
      redirect_to pay_period_path(@pay_period), alert: 'Cannot publish.'
    end
  end

  def export_bank_schedule
    authorize!("export_bank_schedule")
    xlsx = ExportBankScheduleService.new(user: current_user, company: current_company, pay_period: @pay_period).call
    send_data xlsx, filename: export_filename(@pay_period, 'bank_schedule'), type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  end

  def export_paye
    authorize!("export_paye_schedule")
    xlsx = ExportPayeService.new(company: current_company, pay_period: @pay_period).call
    send_data xlsx, filename: export_filename(@pay_period, 'paye_list'), type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  end

  def export_pension
    authorize!("export_pension_list")
    xlsx = ExportPensionService.new(company: current_company, pay_period: @pay_period).call
    send_data xlsx, filename: export_filename(@pay_period, 'pension_list'), type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  end

  def export_tevet
    authorize!("export_tevet")
    xlsx = ExportTevetService.new(company: current_company, pay_period: @pay_period).call
    send_data xlsx, filename: export_filename(@pay_period, 'tevet'), type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  end

  def export_funeral
    authorize!("export_funeral")
    xlsx = ExportFuneralService.new(company: current_company, pay_period: @pay_period).call
    send_data xlsx, filename: export_filename(@pay_period, 'funeral'), type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  end

  def export_medical
    authorize!("export_medical")
    xlsx = ExportMedicalService.new(company: current_company, pay_period: @pay_period).call
    send_data xlsx, filename: export_filename(@pay_period, 'medical'), type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  end

  def export_deductions
    authorize!("export_deductions")
    xlsx = ExportDeductionsService.new(company: current_company, pay_period: @pay_period).call
    send_data xlsx, filename: export_filename(@pay_period, 'deductions'), type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  end

  def export_journal
    authorize!("export_journal_entries")
    xlsx = ExportJournalEntriesService.new(company: current_company, pay_period: @pay_period).call
    send_data xlsx, filename: export_filename(@pay_period, 'journal_entries'), type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  end

  def export_filename(pay_period, prefix)
    suffix = pay_period ? format("%<year>d-%<month>02d", year: pay_period.year, month: pay_period.month) : Date.current.strftime("%Y-%m")
    "#{prefix}_#{suffix}.xlsx"
  end

  def export_reports
    authorize!("export_payslips")
    # Placeholder: later generate zip of reports
    redirect_to pay_period_path(@pay_period), notice: 'Reports export queued.'
  end

  private

  def set_pay_period
    @pay_period = current_company.pay_periods.find(params[:id])
  end

  def pay_period_params
    params.require(:pay_period).permit(:month, :year, :currency_rate)
  end
end
