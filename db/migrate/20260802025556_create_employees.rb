class CreateEmployees < ActiveRecord::Migration[8.1]
  def change
    create_table :employees do |t|
      t.references :company, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.references :import_template, foreign_key: true
      t.string :employee_code
      t.string :first_name
      t.string :last_name
      t.string :department
      t.string :job_title
      t.decimal :salary, precision: 15, scale: 2
      t.date :hire_date
      t.integer :employment_status, null: false, default: 0
      t.integer :onboarding_status, null: false, default: 0
      t.integer :source_row
      t.string :bank_name
      t.string :bank_branch
      t.string :bank_account_number
      t.integer :account_type
      t.string :account_holder_name
      t.string :swift_code
      t.string :mobile_money_number
      t.integer :mobile_money_provider
      t.integer :payment_method

      t.timestamps
    end

    add_index :employees, [ :company_id, :employee_code ], unique: true
  end
end
