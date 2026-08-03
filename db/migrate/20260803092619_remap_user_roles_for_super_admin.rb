class RemapUserRolesForSuperAdmin < ActiveRecord::Migration[8.1]
  def up
    # Remap old enum values:
    # old: admin=0, hr=1, accountant=2
    # new: employee=0, accountant=1, hr=2, admin=3, super_admin=4
    execute <<~SQL
      UPDATE users
      SET role = CASE role
        WHEN 0 THEN 3
        WHEN 1 THEN 2
        WHEN 2 THEN 1
        ELSE role
      END
    SQL

    change_column_null :users, :company_id, true
  end

  def down
    change_column_null :users, :company_id, false

    execute <<~SQL
      UPDATE users
      SET role = CASE role
        WHEN 3 THEN 0
        WHEN 2 THEN 1
        WHEN 1 THEN 2
        ELSE role
      END
    SQL
  end
end
