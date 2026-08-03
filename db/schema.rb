# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_08_03_131500) do
  create_table "active_storage_attachments", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "companies", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "currency_code", default: "MWK", null: false
    t.string "currency_symbol", default: "MK", null: false
    t.string "email_from_address"
    t.string "email_from_name"
    t.string "logo_url"
    t.string "name"
    t.integer "plan", default: 0, null: false
    t.string "primary_color", default: "#0d6efd", null: false
    t.string "subdomain", null: false
    t.datetime "updated_at", null: false
    t.string "whatsapp_api_key"
    t.string "whatsapp_provider"
    t.index ["subdomain"], name: "index_companies_on_subdomain", unique: true
  end

  create_table "company_configs", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.text "value"
    t.index ["company_id", "key"], name: "index_company_configs_on_company_id_and_key", unique: true
    t.index ["company_id"], name: "index_company_configs_on_company_id"
  end

  create_table "company_properties", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.integer "position", default: 0, null: false
    t.string "property_key", null: false
    t.datetime "updated_at", null: false
    t.string "value", null: false
    t.index ["company_id", "property_key", "value"], name: "index_company_properties_on_company_and_key_and_value", unique: true
    t.index ["company_id"], name: "index_company_properties_on_company_id"
  end

  create_table "employees", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "account_holder_name"
    t.integer "account_type"
    t.string "bank_account_number"
    t.string "bank_branch"
    t.string "bank_name"
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.string "department"
    t.string "employee_code"
    t.integer "employment_status", default: 0, null: false
    t.string "first_name"
    t.date "hire_date"
    t.bigint "import_template_id"
    t.string "job_title"
    t.string "last_name"
    t.string "mobile_money_number"
    t.integer "mobile_money_provider"
    t.integer "onboarding_status", default: 0, null: false
    t.integer "payment_method"
    t.decimal "salary", precision: 15, scale: 2
    t.integer "source_row"
    t.string "swift_code"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["company_id", "employee_code"], name: "index_employees_on_company_id_and_employee_code", unique: true
    t.index ["company_id"], name: "index_employees_on_company_id"
    t.index ["import_template_id"], name: "index_employees_on_import_template_id"
    t.index ["user_id"], name: "index_employees_on_user_id"
  end

  create_table "import_templates", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.json "column_mapping"
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.bigint "created_by"
    t.string "name"
    t.string "original_filename"
    t.json "required_columns"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_import_templates_on_company_id"
    t.index ["created_by"], name: "index_import_templates_on_created_by"
  end

  create_table "pay_periods", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.decimal "currency_rate", precision: 10, scale: 4
    t.integer "month"
    t.integer "status", default: 0, null: false
    t.decimal "total_gross", precision: 15, scale: 2
    t.decimal "total_net", precision: 15, scale: 2
    t.datetime "updated_at", null: false
    t.integer "year"
    t.index ["company_id", "month", "year"], name: "index_pay_periods_on_company_id_and_month_and_year", unique: true
    t.index ["company_id"], name: "index_pay_periods_on_company_id"
  end

  create_table "payslips", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.decimal "deductions", precision: 15, scale: 2
    t.bigint "employee_id", null: false
    t.decimal "gross", precision: 15, scale: 2
    t.decimal "net", precision: 15, scale: 2
    t.bigint "pay_period_id", null: false
    t.string "pdf_url"
    t.datetime "updated_at", null: false
    t.index ["employee_id"], name: "index_payslips_on_employee_id"
    t.index ["pay_period_id", "employee_id"], name: "index_payslips_on_pay_period_id_and_employee_id", unique: true
    t.index ["pay_period_id"], name: "index_payslips_on_pay_period_id"
  end

  create_table "role_permissions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.boolean "enabled", default: false, null: false
    t.string "permission_key", null: false
    t.string "role", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "role", "permission_key"], name: "idx_role_permissions_company_role_key", unique: true
    t.index ["company_id"], name: "index_role_permissions_on_company_id"
  end

  create_table "system_configs", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "category"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.text "value"
    t.index ["key"], name: "index_system_configs_on_key", unique: true
  end

  create_table "user_configs", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "data_type"
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.text "value"
    t.index ["user_id", "key"], name: "index_user_configs_on_user_id_and_key", unique: true
    t.index ["user_id"], name: "index_user_configs_on_user_id"
  end

  create_table "users", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "blocked_at"
    t.string "blocked_reason"
    t.bigint "company_id"
    t.datetime "created_at", null: false
    t.string "email"
    t.string "encrypted_password"
    t.string "first_name"
    t.string "last_name"
    t.integer "onboarding_status", default: 0, null: false
    t.string "phone_number"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.integer "role", default: 0, null: false
    t.integer "status", default: 0, null: false
    t.boolean "super_admin", default: false, null: false
    t.boolean "two_factor_enabled", default: false, null: false
    t.string "two_factor_method"
    t.datetime "updated_at", null: false
    t.datetime "verification_sent_at"
    t.string "verification_token"
    t.index ["company_id", "email"], name: "index_users_on_company_id_and_email", unique: true
    t.index ["company_id"], name: "index_users_on_company_id"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["verification_token"], name: "index_users_on_verification_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "company_configs", "companies"
  add_foreign_key "company_properties", "companies"
  add_foreign_key "employees", "companies"
  add_foreign_key "employees", "import_templates"
  add_foreign_key "employees", "users"
  add_foreign_key "import_templates", "companies"
  add_foreign_key "import_templates", "users", column: "created_by"
  add_foreign_key "pay_periods", "companies"
  add_foreign_key "payslips", "employees"
  add_foreign_key "payslips", "pay_periods"
  add_foreign_key "role_permissions", "companies"
  add_foreign_key "user_configs", "users"
  add_foreign_key "users", "companies"
end
