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

ActiveRecord::Schema[8.0].define(version: 2025_11_07_184924) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "payments", force: :cascade do |t|
    t.bigint "payout_id", null: false
    t.string "type", null: false
    t.string "stripe_id", null: false
    t.datetime "created_at_stripe", null: false
    t.text "description"
    t.decimal "amount", precision: 10, scale: 2
    t.string "currency"
    t.decimal "converted_amount", precision: 10, scale: 2
    t.decimal "fees", precision: 10, scale: 2
    t.decimal "net", precision: 10, scale: 2
    t.string "converted_currency"
    t.text "details"
    t.string "customer_id"
    t.string "customer_email"
    t.string "customer_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "eu_classification", default: 0, null: false
    t.index ["customer_id"], name: "index_payments_on_customer_id", where: "(customer_id IS NOT NULL)"
    t.index ["payout_id", "stripe_id"], name: "index_payments_on_payout_id_and_stripe_id", unique: true
    t.index ["payout_id"], name: "index_payments_on_payout_id"
    t.index ["stripe_id"], name: "index_payments_on_stripe_id"
  end

  create_table "payouts", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name", null: false
    t.date "period_start", null: false
    t.date "period_end", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "period_start", "period_end"], name: "index_payouts_on_user_id_and_period_start_and_period_end"
    t.index ["user_id"], name: "index_payouts_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "transactions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "transaction_id", null: false
    t.datetime "created_at_stripe", null: false
    t.string "status"
    t.string "decline_reason"
    t.string "card_address_country"
    t.string "card_issue_country"
    t.string "shipping_address_country"
    t.integer "location_confidence_score", default: 0
    t.integer "eu_classification", default: 0, null: false
    t.jsonb "raw_data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["eu_classification"], name: "index_transactions_on_eu_classification"
    t.index ["transaction_id"], name: "index_transactions_on_transaction_id", unique: true
    t.index ["user_id"], name: "index_transactions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "payments", "payouts"
  add_foreign_key "payouts", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "transactions", "users"
end
