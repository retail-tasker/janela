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

ActiveRecord::Schema[8.1].define(version: 2026_09_15_034523) do
  create_table "customers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "region", null: false
    t.datetime "updated_at", null: false
  end

  create_table "janela_snapshots", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.json "filters", null: false
    t.string "name", null: false
    t.json "panes", null: false
    t.datetime "taken_at", null: false
    t.datetime "updated_at", null: false
    t.index ["taken_at"], name: "index_janela_snapshots_on_taken_at"
  end

  create_table "orders", force: :cascade do |t|
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.datetime "created_at", null: false
    t.integer "customer_id", null: false
    t.date "placed_on", null: false
    t.string "status", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_orders_on_customer_id"
  end

  add_foreign_key "orders", "customers"
end
