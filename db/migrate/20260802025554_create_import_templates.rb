class CreateImportTemplates < ActiveRecord::Migration[8.1]
  def change
    create_table :import_templates do |t|
      t.references :company, null: false, foreign_key: true
      t.string :name
      t.string :original_filename
      t.json :column_mapping
      t.json :required_columns
      t.integer :status, null: false, default: 0
      t.bigint :created_by

      t.timestamps
    end

    add_foreign_key :import_templates, :users, column: :created_by
    add_index :import_templates, :created_by
  end
end
