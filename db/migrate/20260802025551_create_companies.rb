class CreateCompanies < ActiveRecord::Migration[8.1]
  def change
    create_table :companies do |t|
      t.string :name
      t.string :logo_url
      t.string :currency_code, null: false, default: "MWK"
      t.string :currency_symbol, null: false, default: "MK"
      t.integer :plan, null: false, default: 0
      t.string :whatsapp_provider
      t.string :whatsapp_api_key
      t.string :email_from_name
      t.string :email_from_address

      t.timestamps
    end
  end
end
