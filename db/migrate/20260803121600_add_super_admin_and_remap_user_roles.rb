class AddSuperAdminAndRemapUserRoles < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :super_admin, :boolean, null: false, default: false

    execute <<~SQL
      UPDATE users
      SET super_admin = TRUE
      WHERE role = 4
    SQL

    execute <<~SQL
      UPDATE users
      SET role = CASE
        WHEN role = 3 THEN 0
        WHEN role = 2 THEN 1
        WHEN role = 1 THEN 2
        WHEN role = 4 THEN 0
        ELSE 1
      END
    SQL
  end

  def down
    execute <<~SQL
      UPDATE users
      SET role = CASE
        WHEN super_admin = TRUE THEN 4
        WHEN role = 0 THEN 3
        WHEN role = 1 THEN 2
        WHEN role = 2 THEN 1
        ELSE 0
      END
    SQL

    remove_column :users, :super_admin
  end
end
