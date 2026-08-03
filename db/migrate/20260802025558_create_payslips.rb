class CreatePayslips < ActiveRecord::Migration[8.1]
  def change
    create_table :payslips do |t|
      t.references :pay_period, null: false, foreign_key: true
      t.references :employee, null: false, foreign_key: true
      t.decimal :gross, precision: 15, scale: 2
      t.decimal :deductions, precision: 15, scale: 2
      t.decimal :net, precision: 15, scale: 2
      t.string :pdf_url

      t.timestamps
    end

    add_index :payslips, [ :pay_period_id, :employee_id ], unique: true
  end
end
