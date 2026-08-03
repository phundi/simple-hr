class EmployeesController < ApplicationController
  before_action :set_employee, only: [ :show, :edit, :update, :destroy, :block, :unblock ]

  def index
    @employees = current_company.employees.order(created_at: :desc)
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
  end

  def create
    @employee = current_company.employees.new(employee_params)

    if @employee.save
      redirect_to employees_path, notice: "Employee created successfully."
    else
      load_department_options
      render :new, status: :unprocessable_entity
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
      :onboarding_status,
      :employment_status
    )
  end

  def load_department_options
    @department_options = current_company.company_properties
      .where(property_key: "department")
      .order(:position, :value)
      .pluck(:value)
  end
end
