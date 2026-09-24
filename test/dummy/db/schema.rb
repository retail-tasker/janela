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

ActiveRecord::Schema[8.1].define(version: 2026_09_24_134036) do
  create_table "customers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "region", null: false
    t.datetime "updated_at", null: false
  end

  create_table "janela_frames", force: :cascade do |t|
    t.integer "columns", default: 3, null: false
    t.datetime "created_at", null: false
    t.integer "gap", default: 4, null: false
    t.string "key"
    t.string "name", null: false
    t.integer "owner_id"
    t.string "owner_type"
    t.datetime "updated_at", null: false
    t.index ["owner_type", "owner_id", "key"], name: "index_janela_frames_on_owner_type_and_owner_id_and_key", unique: true
    t.index ["owner_type", "owner_id"], name: "index_janela_frames_on_owner"
  end

  create_table "janela_panes", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.string "dimension"
    t.integer "frame_id", null: false
    t.string "granularity"
    t.string "heading"
    t.string "kind", default: "query", null: false
    t.integer "limit"
    t.string "link"
    t.string "measure"
    t.string "model"
    t.string "partial"
    t.integer "position", null: false
    t.string "renderer", default: "table", null: false
    t.integer "span", default: 1, null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["frame_id", "position"], name: "index_janela_panes_on_frame_id_and_position"
  end

  create_table "janela_snapshots", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.json "filters", null: false
    t.string "name", null: false
    t.integer "owner_id"
    t.string "owner_type"
    t.json "panes", null: false
    t.datetime "taken_at", null: false
    t.datetime "updated_at", null: false
    t.index ["owner_type", "owner_id"], name: "index_janela_snapshots_on_owner"
    t.index ["taken_at"], name: "index_janela_snapshots_on_taken_at"
  end

  create_table "orders", force: :cascade do |t|
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.string "channel"
    t.datetime "created_at", null: false
    t.integer "customer_id", null: false
    t.boolean "expedited", default: false, null: false
    t.date "placed_on", null: false
    t.string "status", null: false
    t.string "type"
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_orders_on_customer_id"
    t.index ["type"], name: "index_orders_on_type"
  end

  add_foreign_key "janela_panes", "janela_frames", column: "frame_id"
  add_foreign_key "orders", "customers"
end
