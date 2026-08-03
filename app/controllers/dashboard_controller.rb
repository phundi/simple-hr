class DashboardController < ApplicationController
  def index
    @company = current_company

    @employees_count = @company.employees.count
    @payroll_eligible_count = @company.employees.payroll_eligible.count
    @pending_verification_count = @company.employees.onboarding_status_unverified.count
    @blocked_employees_count = @company.employees.employment_status_blocked.count

    @current_pay_period = @company.pay_periods.find_by(month: Date.current.month, year: Date.current.year)
    @current_pay_period ||= @company.pay_periods.published.order(year: :desc, month: :desc).first
    @export_pay_periods = @company.pay_periods.order(year: :desc, month: :desc)
    @payroll_this_month = @current_pay_period&.total_net.to_d

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
