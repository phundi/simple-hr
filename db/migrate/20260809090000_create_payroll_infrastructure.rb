# frozen_string_literal: true

class CreatePayrollInfrastructure < ActiveRecord::Migration[8.1]
  def change
    create_table :payroll_components do |t|
      t.references :company, null: false, foreign_key: true
      t.string :name, null: false
      t.string :code, null: false
      t.string :category, null: false # allowance, deduction, employer_benefit, statutory
      t.string :calculation_type, null: false # fixed, percent_basic, percent_gross, percent_gross_taxable, fixed_by_grade
      t.decimal :default_rate, precision: 10, scale: 4, default: 0.0, null: false
      t.decimal :default_amount, precision: 15, scale: 2
      t.boolean :taxable, default: true, null: false
      t.boolean :affects_paye, default: true, null: false
      t.boolean :enabled_by_default, default: true, null: false
      t.integer :position
      t.json :metadata

      t.timestamps
    end

    add_index :payroll_components, [:company_id, :code], unique: true, name: 'index_payroll_components_on_company_and_code'

    create_table :employee_payroll_components do |t|
      t.references :employee, null: false, foreign_key: true
      t.references :payroll_component, null: false, foreign_key: true
      t.boolean :enabled, default: true, null: false
      t.decimal :custom_rate, precision: 10, scale: 4
      t.decimal :custom_amount, precision: 15, scale: 2
      t.date :effective_from

      t.timestamps
    end

    create_table :employee_advances do |t|
      t.references :employee, null: false, foreign_key: true
      t.references :company, null: false, foreign_key: true
      t.string :advance_type, default: 'salary_advance', null: false
      t.decimal :amount, precision: 15, scale: 2, null: false
      t.decimal :balance, precision: 15, scale: 2, null: false
      t.decimal :monthly_installment, precision: 15, scale: 2
      t.string :status, default: 'active', null: false # active, repaid, cancelled
      t.date :issue_date
      t.text :notes

      t.timestamps
    end

    # Extend payslips safely, keeping existing data
    change_table :payslips, bulk: true do |t|
      t.decimal :basic_salary, precision: 15, scale: 2
      t.json :allowances
      t.json :employer_benefits
      t.json :deductions_breakdown
      t.decimal :total_employer_benefits, precision: 15, scale: 2
      t.decimal :total_remuneration, precision: 15, scale: 2
      t.decimal :taxable_income, precision: 15, scale: 2
      t.decimal :paye, precision: 15, scale: 2
      t.decimal :pension_employee, precision: 15, scale: 2
    end

    # Company level payroll settings
    create_table :company_payroll_settings do |t|
      t.references :company, null: false, foreign_key: true
      t.decimal :house_allowance_rate, precision: 10, scale: 4, default: 0.10, null: false
      t.decimal :pension_employer_rate, precision: 10, scale: 4, default: 0.10, null: false
      t.decimal :pension_employee_rate, precision: 10, scale: 4, default: 0.05, null: false
      t.decimal :funeral_rate, precision: 10, scale: 4, default: 0.01, null: false
      t.decimal :tevet_rate, precision: 10, scale: 4, default: 0.01, null: false
      t.decimal :life_assurance_rate, precision: 10, scale: 4, default: 0.01, null: false
      t.decimal :pension_admin_rate, precision: 10, scale: 4, default: 0.003, null: false
      t.decimal :admin_vat_rate, precision: 10, scale: 4, default: 0.165, null: false
      t.json :paye_brackets
      t.json :medical_grades

      t.timestamps
    end

    unless index_exists?(:company_payroll_settings, :company_id, unique: true)
      add_index :company_payroll_settings, :company_id, unique: true
    end
  end
end
