class AddSystemConfigEnableSubdomainRedirect < ActiveRecord::Migration[8.1]
  def change
    reversible do |dir|
      dir.up do
        execute <<~SQL
          INSERT INTO system_configs (`key`, `value`, data_type, category, description, created_at, updated_at)
          VALUES (
            'enable_subdomain_redirect',
            'false',
            'Security',
            'If true, users are redirected to subdomain.company.com. If false, all users stay on main domain',
            NOW(),
            NOW()
          )
          ON DUPLICATE KEY UPDATE
            value = VALUES(value),
            category = VALUES(category),
            description = VALUES(description),
            updated_at = VALUES(updated_at)
        SQL
      end

      dir.down do
        execute "DELETE FROM system_configs WHERE `key` = 'enable_subdomain_redirect'"
      end
    end
  end
end
