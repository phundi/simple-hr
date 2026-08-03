class CreateCompanyConfigs < ActiveRecord::Migration[8.1]
  def change
    create_table :company_configs do |t|
      t.references :company, null: false, foreign_key: true
      t.string :key, null: false
      t.text :value

      t.timestamps
    end
  end
end
