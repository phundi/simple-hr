# frozen_string_literal: true

class EmployeesController < ApplicationController
  before_action :set_employee, only: [ :show, :edit, :update, :destroy, :block, :unblock ]
  # permission_key: manage_employees
  before_action -> { authorize!("manage_employees") }, only: [ :new, :create, :edit, :update, :destroy, :block, :unblock ]
  # permission_key: view_employee_sensitive
  before_action -> { authorize!("view_employee_sensitive") }, only: [ :index, :show ]
  # permission_key: export_employee_data

  def index
    @departments = current_company.company_properties.where(property_key: 'department').order(:position).pluck(:value)
    @projects = current_company.company_properties.where(property_key: 'project').order(:position).pluck(:value)
    @payment_methods = Employee.payment_methods.keys
    @pay_periods = current_company.pay_periods.order(year: :desc, month: :desc)

    @sort_column = params[:sort].presence_in(%w[name employee_code salary]) || 'created_at'
    @sort_direction = params[:direction].presence_in(%w[asc desc]) || 'desc'

    scope = current_company.employees

    if params[:q].present?
      q = params[:q].strip
      scope = scope.where("first_name LIKE ? OR last_name LIKE ? OR employee_code LIKE ?", "%#{q}%", "%#{q}%", "%#{q}%")
    end

    if params[:department].present?
      scope = scope.where(department: params[:department])
    end

    if params[:project].present?
      scope = scope.where(project: params[:project])
    end

    if params[:payment_method].present?
      scope = scope.where(payment_method: Employee.payment_methods[params[:payment_method]] ? params[:payment_method] : nil)
    end

    if params[:status].present?
      case params[:status]
      when 'active'
        scope = scope.where(employment_status: Employee.employment_statuses[:active])
      when 'blocked'
        scope = scope.where(employment_status: Employee.employment_statuses[:blocked])
      when 'unverified'
        scope = scope.where(onboarding_status: Employee.onboarding_statuses[:unverified])
      end
    end

    case @sort_column
    when 'name'
      scope = scope.order(first_name: @sort_direction, last_name: @sort_direction)
    when 'employee_code'
      scope = scope.order(employee_code: @sort_direction)
    when 'salary'
      scope = scope.order(salary: @sort_direction)
    else
      scope = scope.order(created_at: @sort_direction)
    end

    @current_pay_period = if params[:pay_period_id].present?
      @pay_periods.find_by(id: params[:pay_period_id])
    else
      @pay_periods.find_by(month: Date.current.month, year: Date.current.year)
    end

    @employees = scope

    if @current_pay_period
      @payslips_map = @current_pay_period.payslips.where(employee_id: @employees.pluck(:id)).index_by(&:employee_id)
      @totals = {
        gross: @payslips_map.values.map { |p| p.gross.to_d }.sum || 0.to_d,
        net: @payslips_map.values.map { |p| p.net.to_d }.sum || 0.to_d,
        paye: @payslips_map.values.map { |p| p.paye.to_d }.sum || 0.to_d
      }
    else
      @payslips_map = {}
      @totals = nil
    end
  end

  def show
  end

  def new
    @employee = current_company.employees.new(
      onboarding_status: :unverified,
      employment_status: :active,
      payment_method: :cash
    )
    load_department_options
    # Load payroll components and medical grades for quick-add
    @payroll_components = current_company.payroll_components.order(:position)
    @medical_grades = (current_company.company_payroll_setting && current_company.company_payroll_setting.medical_grades) || {}
  end

  def create
    if params[:employee].blank?
      @employee = current_company.employees.new
      @employee.errors.add(:base, "Employee details missing. Please fill required fields")
      load_department_options
      render :new, status: :unprocessable_entity and return
    end

    @employee = current_company.employees.new(employee_params)

    # If user selected bank but provided no bank details, switch to cash to avoid validation crash
    if @employee.payment_method.to_s == 'bank' && @employee.bank_name.blank? && @employee.bank_account_number.blank?
      @employee.payment_method = 'cash'
    end

    # auto-generate DEMO code if blank and quick_add param present
    if params[:quick_add].present? && @employee.employee_code.blank?
      max_demo = current_company.employees.where("employee_code LIKE ?", "DEMO%").pluck(:employee_code).map { |c| c.to_s.gsub(/\D/, '').to_i }.max || 0
      @employee.employee_code = format("DEMO%03d", max_demo + 1)
      @employee.onboarding_status = :verified
      @employee.employment_status = :active
    end

    ActiveRecord::Base.transaction do
      if @employee.save
        if params[:quick_add].present?
          # create employee payroll components
          Array(params[:components]).each do |comp|
            next unless comp && comp[:payroll_component_id].present?
            EmployeePayrollComponent.create!(employee: @employee,
                                             payroll_component_id: comp[:payroll_component_id],
                                             enabled: comp[:enabled].in?([true, 'true', '1']) ,
                                             custom_rate: comp[:custom_rate].presence,
                                             custom_amount: comp[:custom_amount].presence,
                                             effective_from: Date.current)
          end

          # create advance if provided
          if params[:advance_amount].present?
            EmployeeAdvance.create!(employee: @employee, company: current_company,
                                    amount: params[:advance_amount].to_d,
                                    balance: params[:advance_amount].to_d,
                                    monthly_installment: params[:advance_monthly_installment].presence)
          end

          # create or find pay period for current month/year (draft)
          period = current_company.pay_periods.find_or_create_by!(month: Date.current.month, year: Date.current.year) do |pp|
            pp.status = :draft
          end

          # prepare settings for computation
          settings = current_company.company_payroll_setting ? {
            house_allowance_rate: current_company.company_payroll_setting.house_allowance_rate,
            pension_employee_rate: current_company.company_payroll_setting.pension_employee_rate,
            pension_employer_rate: current_company.company_payroll_setting.pension_employer_rate,
            funeral_rate: current_company.company_payroll_setting.funeral_rate,
            tevet_rate: current_company.company_payroll_setting.tevet_rate,
            life_assurance_rate: current_company.company_payroll_setting.life_assurance_rate,
            pension_admin_rate: current_company.company_payroll_setting.pension_admin_rate,
            admin_vat_rate: current_company.company_payroll_setting.admin_vat_rate,
            paye_brackets: current_company.company_payroll_setting.paye_brackets || MalawiPayeCalculator::DEFAULT_BRACKETS,
            medical_grades: current_company.company_payroll_setting.medical_grades || {}
          } : {}

          computation = PayrollComputationService.new(Struct.new(:salary, :medical_grade).new(@employee.salary.to_f, @employee.respond_to?(:medical_grade) ? @employee.medical_grade : nil), period, settings, @employee.employee_advances, @employee.employee_payroll_components).call

          payslip = Payslip.find_or_initialize_by(pay_period: period, employee: @employee)
          payslip.basic_salary = computation[:basic_salary]
          payslip.allowances = computation[:allowances]
          payslip.employer_benefits = computation[:employer_benefits]
          payslip.total_employer_benefits = computation[:total_employer_benefits]
          payslip.total_remuneration = computation[:total_remuneration]
          payslip.taxable_income = computation[:taxable_income]
          payslip.paye = computation[:deductions_breakdown][:paye]
          payslip.pension_employee = computation[:deductions_breakdown][:pension_employee]
          payslip.gross = computation[:gross_income]
          payslip.net = computation[:net_pay]
          payslip.deductions_breakdown = computation[:deductions_breakdown]
          payslip.save!

          redirect_to employee_payroll_path(@employee, tab: 'general'), notice: "Employee created and added to #{Date::MONTHNAMES[Date.current.month]} #{Date.current.year} payroll"
          return
        end

        redirect_to employees_path, notice: "Employee created successfully."
      else
        load_department_options
        render :new, status: :unprocessable_entity
      end
    end
  end

  def edit
    load_department_options
  end

  def update
    if @employee.update(employee_params)
      redirect_to employees_path, notice: "Employee updated successfully."
    else
      load_department_options
      render :edit, status: :unprocessable_entity
    end
  end

  # POST /employees/calculate_preview
  def calculate_preview
    authorize!("manage_employees")

    salary = params[:basic_salary].to_f
    components = params[:components] || []

    settings = current_company.company_payroll_setting ? {
      house_allowance_rate: current_company.company_payroll_setting.house_allowance_rate,
      pension_employee_rate: current_company.company_payroll_setting.pension_employee_rate,
      pension_employer_rate: current_company.company_payroll_setting.pension_employer_rate,
      funeral_rate: current_company.company_payroll_setting.funeral_rate,
      tevet_rate: current_company.company_payroll_setting.tevet_rate,
      life_assurance_rate: current_company.company_payroll_setting.life_assurance_rate,
      pension_admin_rate: current_company.company_payroll_setting.pension_admin_rate,
      admin_vat_rate: current_company.company_payroll_setting.admin_vat_rate,
      paye_brackets: current_company.company_payroll_setting.paye_brackets || MalawiPayeCalculator::DEFAULT_BRACKETS,
      medical_grades: current_company.company_payroll_setting.medical_grades || {}
    } : {}

    employee_struct = Struct.new(:salary, :medical_grade).new(salary, params[:medical_grade])

    # Build temporary EmployeePayrollComponent objects from params
    temp_components = Array(components).map do |comp|
      payroll_component = current_company.payroll_components.find_by(id: comp[:payroll_component_id])
      next unless payroll_component
      EmployeePayrollComponent.new(employee_id: nil, payroll_component: payroll_component, enabled: comp[:enabled].in?([true, 'true', '1']), custom_rate: comp[:custom_rate].presence, custom_amount: comp[:custom_amount].presence)
    end.compact

    computation = PayrollComputationService.new(employee_struct, nil, settings, [], temp_components).call

    render json: {
      gross: computation[:gross_income],
      paye: computation[:deductions_breakdown][:paye],
      pension: computation[:deductions_breakdown][:pension_employee],
      net: computation[:net_pay],
      allowances: computation[:allowances],
      employer_benefits: computation[:employer_benefits]
    }
  end

  # POST /employees/bulk_action
  def bulk_action
    authorize!("manage_employees")
    ids = Array(params[:employee_ids]).map(&:to_i)
    action = params[:bulk_action]

    if ids.empty? || action.blank?
      redirect_back fallback_location: employees_path, alert: "No employees selected or action missing"
      return
    end

    case action
    when 'block'
      current_company.employees.where(id: ids).update_all(employment_status: Employee.employment_statuses[:blocked])
      notice = "Selected employees blocked"
    when 'unblock'
      current_company.employees.where(id: ids).update_all(employment_status: Employee.employment_statuses[:active])
      notice = "Selected employees unblocked"
    when 'add_to_payroll'
      period = current_company.pay_periods.find_or_create_by!(month: Date.current.month, year: Date.current.year)
      employees = current_company.employees.where(id: ids)
      employees.find_each do |emp|
        settings = current_company.company_payroll_setting
        employee_struct = Struct.new(:salary, :medical_grade).new(emp.salary.to_f, emp.respond_to?(:medical_grade) ? emp.medical_grade : nil)
        computation = PayrollComputationService.new(employee_struct, period, settings, emp.employee_advances, emp.employee_payroll_components).call
        payslip = Payslip.find_or_initialize_by(pay_period: period, employee: emp)
        payslip.basic_salary = computation[:basic_salary]
        payslip.gross = computation[:gross_income]
        payslip.net = computation[:net_pay]
        payslip.paye = computation[:deductions_breakdown][:paye]
        payslip.save!
      end
      notice = "Added selected employees to #{Date::MONTHNAMES[period.month]} #{period.year} payroll"
    else
      redirect_back fallback_location: employees_path, alert: "Unknown bulk action"
      return
    end

    redirect_back fallback_location: employees_path, notice: notice
  end

  def destroy
    @employee.destroy!
    redirect_to employees_path, notice: "Employee deleted successfully."
  rescue ActiveRecord::RecordNotDestroyed => e
    redirect_to employees_path, alert: "Could not delete employee: #{e.record.errors.full_messages.to_sentence}"
  end

  def block
    @employee.block!
    redirect_back fallback_location: root_path, notice: "Employee blocked successfully."
  rescue ActiveRecord::RecordInvalid => e
    redirect_back fallback_location: root_path, alert: "Could not block employee: #{e.record.errors.full_messages.to_sentence}"
  end

  def unblock
    @employee.unblock!
    redirect_back fallback_location: root_path, notice: "Employee unblocked successfully."
  rescue ActiveRecord::RecordInvalid => e
    redirect_back fallback_location: root_path, alert: "Could not unblock employee: #{e.record.errors.full_messages.to_sentence}"
  end

  private

  def set_employee
    @employee = current_company.employees.find(params[:id])
  end

  def employee_params
    if params[:employee].present?
      params.require(:employee).permit(
        :user_id,
        :employee_code,
        :first_name,
        :last_name,
        :department,
        :job_title,
        :salary,
        :payment_method,
        :bank_name,
        :bank_account_number,
        :mobile_money_number,
        :mobile_money_provider,
        :email,
        :phone,
        :project,
        :bank_branch,
        :swift,
        :account_type,
        :gender,
        :medical_grade,
        :onboarding_status,
        :employment_status
      )
    else
      # fallback for quick-add which posts top-level fields
      params.permit(
        :user_id,
        :employee_code,
        :first_name,
        :last_name,
        :department,
        :job_title,
        :salary,
        :payment_method,
        :bank_name,
        :bank_account_number,
        :mobile_money_number,
        :mobile_money_provider,
        :email,
        :phone,
        :project,
        :bank_branch,
        :swift,
        :account_type,
        :gender,
        :medical_grade,
        :onboarding_status,
        :employment_status
      )
    end
  end

  def load_department_options
    @department_options = current_company.company_properties
      .where(property_key: "department")
      .order(:position, :value)
      .pluck(:value)
  end
end
