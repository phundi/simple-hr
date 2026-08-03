class CreateUserConfigs < ActiveRecord::Migration[8.1]
  def change
    create_table :user_configs do |t|
      t.references :user, null: false, foreign_key: true
      t.string :key, null: false
      t.text :value
      t.string :data_type

      t.timestamps
    end
  end
end
