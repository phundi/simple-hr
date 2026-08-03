class RemoveDataTypeFromCompanyConfigs < ActiveRecord::Migration[8.1]
  def change
    remove_column :company_configs, :data_type, :string
  end
end
