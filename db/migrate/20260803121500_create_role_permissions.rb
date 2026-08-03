class CreateRolePermissions < ActiveRecord::Migration[8.1]
  def change
    create_table :role_permissions do |t|
      t.references :company, null: false, foreign_key: true
      t.string :role, null: false
      t.string :permission_key, null: false
      t.boolean :enabled, null: false, default: false

      t.timestamps
    end

    add_index :role_permissions, [ :company_id, :role, :permission_key ], unique: true, name: "idx_role_permissions_company_role_key"
  end
end
