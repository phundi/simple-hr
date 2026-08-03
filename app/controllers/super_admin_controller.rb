class SuperAdminController < SuperAdmin::ApplicationController
  skip_before_action :require_super_admin!, only: :stop_impersonating

  def index
    @companies = Company
      .left_joins(:users, :employees, :pay_periods)
      .select(
        "companies.*",
        "COUNT(DISTINCT users.id) AS users_count",
        "COUNT(DISTINCT employees.id) AS employees_count",
        "COUNT(DISTINCT pay_periods.id) AS pay_periods_count"
      )
      .group("companies.id")
      .order(:name)

    @stats = {
      companies: Company.count,
      users: User.count,
      employees: Employee.count,
      pay_periods: PayPeriod.count,
      payslips: Payslip.count
    }
  end

  def impersonate
    company = Company.find(params[:company_id])
    target = company.users.status_active.order(:id).first || company.users.order(:id).first

    unless target
      redirect_to super_admin_dashboard_path, alert: "No users available to impersonate for #{company.name}." and return
    end

    session[:super_admin_user_id] ||= current_user.id
    sign_in(target)
    session[:company_id] = company.id

    redirect_to authenticated_root_path, notice: "Now impersonating #{target.email} (#{company.name})."
  end

  def stop_impersonating
    original_user = User.find_by(id: session[:super_admin_user_id])
    session.delete(:super_admin_user_id)

    unless original_user&.super_admin?
      redirect_to new_user_session_path, alert: "Original super admin session not found." and return
    end

    sign_in(original_user)
    session[:company_id] = nil
    redirect_to super_admin_dashboard_path, notice: "Returned to SuperAdmin session."
  end

  private

  def require_super_admin!
    if action_name == "stop_impersonating"
      original_user = User.find_by(id: session[:super_admin_user_id])
      return if current_user&.super_admin? || original_user&.super_admin?
    end

    super
  end

end
