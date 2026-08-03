class AddRoleToUsers < ActiveRecord::Migration[8.1]
  def change
    return if column_exists?(:users, :role)

    add_column :users, :role, :string
  end
end
