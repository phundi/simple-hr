class AddSubdomainAndPrimaryColorToCompanies < ActiveRecord::Migration[8.1]
  class MigrationCompany < ActiveRecord::Base
    self.table_name = "companies"
  end

  def up
    add_column :companies, :subdomain, :string
    add_column :companies, :primary_color, :string, default: "#0d6efd", null: false

    MigrationCompany.reset_column_information
    MigrationCompany.find_each do |company|
      base = company.name.to_s.parameterize.presence || "company"
      candidate = base
      suffix = 1

      while MigrationCompany.where.not(id: company.id).exists?(subdomain: candidate)
        candidate = "#{base}-#{suffix}"
        suffix += 1
      end

      company.update_columns(subdomain: candidate)
    end

    change_column_null :companies, :subdomain, false
    add_index :companies, :subdomain, unique: true
  end

  def down
    remove_index :companies, :subdomain
    remove_column :companies, :subdomain
    remove_column :companies, :primary_color
  end
end
