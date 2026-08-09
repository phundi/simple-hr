class DashboardController < ApplicationController
  before_action :authenticate_user!
  skip_before_action :set_current_company

  def smart
    if current_user&.super_admin?
      redirect_to super_admin_dashboard_path
    else
      redirect_to company_dashboard_path
    end
  end

  def index
    @current_company = current_user.company
    unless @current_company
      redirect_to new_company_path, alert: "Please create your company first" and return
    end

    @company = @current_company

    @employees_count = @company.employees.count
    @payroll_eligible_count = @company.employees.payroll_eligible.count
    @pending_verification_count = @company.employees.onboarding_status_unverified.count
    @blocked_employees_count = @company.employees.employment_status_blocked.count

    @current_pay_period = @company.pay_periods.find_by(month: Date.current.month, year: Date.current.year)
    @current_pay_period ||= @company.pay_periods.published.order(year: :desc, month: :desc).first
    @export_pay_periods = @company.pay_periods.order(year: :desc, month: :desc)
    @payroll_this_month = @current_pay_period&.total_net.to_d

    if can_render?("view_reports") && @current_pay_period
      @total_paye_this_month = @current_pay_period.payslips.sum(:paye) || 0.to_d
      @total_pension_this_month = @current_pay_period.payslips.sum(:pension_employee) || 0.to_d
      @total_employer_benefits_cost = @current_pay_period.payslips.sum(:total_employer_benefits) || 0.to_d
    else
      @total_paye_this_month = 0.to_d
      @total_pension_this_month = 0.to_d
      @total_employer_benefits_cost = 0.to_d
    end

    @payroll_trend = payroll_trend_data(@company)
    @employees_by_department = employees_by_department_data(@company)
  end

  private

  def payroll_trend_data(company)
    month_points = (0..5).map { |offset| Date.current.beginning_of_month - offset.months }.reverse

    month_points.each_with_object({}) do |month_date, result|
      total = company.pay_periods
        .where(month: month_date.month, year: month_date.year)
        .sum(:total_net)

      result[month_date.strftime("%b %Y")] = total.to_f
    end
  end

  def employees_by_department_data(company)
    company.employees
      .group(Arel.sql("COALESCE(NULLIF(department, ''), 'Unassigned')"))
      .count
  end
end
