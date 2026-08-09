# frozen_string_literal: true

class EmployeePayrollComponent < ApplicationRecord
  belongs_to :employee
  belongs_to :payroll_component

  validates :employee_id, :payroll_component_id, presence: true
end
