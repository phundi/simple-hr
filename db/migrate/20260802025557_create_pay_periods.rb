class CreatePayPeriods < ActiveRecord::Migration[8.1]
  def change
    create_table :pay_periods do |t|
      t.references :company, null: false, foreign_key: true
      t.integer :month
      t.integer :year
      t.integer :status, null: false, default: 0
      t.decimal :total_gross, precision: 15, scale: 2
      t.decimal :total_net, precision: 15, scale: 2
      t.decimal :currency_rate, precision: 10, scale: 4

      t.timestamps
    end

    add_index :pay_periods, [ :company_id, :month, :year ], unique: true
  end
end
