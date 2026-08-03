class CreateSystemConfigs < ActiveRecord::Migration[8.1]
  def change
    create_table :system_configs do |t|
      t.string :key, null: false
      t.text :value
      t.string :data_type
      t.string :category
      t.text :description

      t.timestamps
    end

    add_index :system_configs, :key, unique: true
  end
end
