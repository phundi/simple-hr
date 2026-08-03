class CreateCompanyProperties < ActiveRecord::Migration[8.1]
  def change
    create_table :company_properties do |t|
      t.references :company, null: false, foreign_key: true
      t.string :property_key, null: false
      t.string :value, null: false
      t.integer :position, default: 0, null: false

      t.timestamps
    end
  end
end
