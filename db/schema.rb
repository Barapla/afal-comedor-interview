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

ActiveRecord::Schema[8.1].define(version: 2026_06_18_142326) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "daily_menus", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "menu_date", null: false
    t.datetime "updated_at", null: false
    t.index ["menu_date"], name: "index_daily_menus_on_menu_date", unique: true
  end

  create_table "dishes", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.integer "price_cents", null: false
    t.datetime "updated_at", null: false
  end

  create_table "guests", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_guests_on_user_id"
  end

  create_table "menu_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "daily_menu_id", null: false
    t.bigint "dish_id", null: false
    t.integer "stock", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["daily_menu_id", "dish_id"], name: "index_menu_items_on_daily_menu_id_and_dish_id", unique: true
    t.index ["daily_menu_id"], name: "index_menu_items_on_daily_menu_id"
    t.index ["dish_id"], name: "index_menu_items_on_dish_id"
  end

  create_table "order_guests", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "guest_id", null: false
    t.bigint "order_id", null: false
    t.datetime "updated_at", null: false
    t.index ["guest_id"], name: "index_order_guests_on_guest_id"
    t.index ["order_id"], name: "index_order_guests_on_order_id", unique: true
  end

  create_table "order_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "menu_item_id", null: false
    t.bigint "order_id", null: false
    t.integer "price_cents", null: false
    t.datetime "updated_at", null: false
    t.index ["menu_item_id"], name: "index_order_items_on_menu_item_id"
    t.index ["order_id", "menu_item_id"], name: "index_order_items_on_order_id_and_menu_item_id", unique: true
    t.index ["order_id"], name: "index_order_items_on_order_id"
  end

  create_table "orders", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "daily_menu_id", null: false
    t.string "status", default: "pending", null: false
    t.integer "subsidy_cents", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["daily_menu_id"], name: "index_orders_on_daily_menu_id"
    t.index ["user_id"], name: "index_orders_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "name", null: false
    t.string "password_digest", null: false
    t.string "role", default: "employee", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "guests", "users"
  add_foreign_key "menu_items", "daily_menus"
  add_foreign_key "menu_items", "dishes"
  add_foreign_key "order_guests", "guests"
  add_foreign_key "order_guests", "orders"
  add_foreign_key "order_items", "menu_items"
  add_foreign_key "order_items", "orders"
  add_foreign_key "orders", "daily_menus"
  add_foreign_key "orders", "users"
  add_foreign_key "sessions", "users"
end
