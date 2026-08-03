class RemoveDataTypeFromSystemConfigs < ActiveRecord::Migration[8.1]
  def change
    remove_column :system_configs, :data_type, :string
  end
end
