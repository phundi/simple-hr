class AddIndexesForConfigAndPropertyTables < ActiveRecord::Migration[8.1]
  def change
    add_index :company_configs, [ :company_id, :key ], unique: true
    add_index :user_configs, [ :user_id, :key ], unique: true
    add_index :company_properties, [ :company_id, :property_key, :value ], unique: true, name: "index_company_properties_on_company_and_key_and_value"
  end
end
