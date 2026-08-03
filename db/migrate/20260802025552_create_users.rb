class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.references :company, null: false, foreign_key: true
      t.string :first_name
      t.string :last_name
      t.string :email
      t.string :phone_number
      t.string :encrypted_password
      t.integer :role, null: false, default: 0
      t.integer :status, null: false, default: 0
      t.integer :onboarding_status, null: false, default: 0
      t.string :verification_token
      t.datetime :verification_sent_at
      t.boolean :two_factor_enabled, null: false, default: false
      t.string :two_factor_method
      t.datetime :blocked_at
      t.string :blocked_reason

      t.timestamps
    end

    add_index :users, [ :company_id, :email ], unique: true
    add_index :users, :verification_token, unique: true
  end
end
