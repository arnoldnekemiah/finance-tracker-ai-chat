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

ActiveRecord::Schema[8.0].define(version: 2025_11_22_143115) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "chat_messages", force: :cascade do |t|
    t.string "firebase_uid", null: false
    t.string "conversation_id", null: false
    t.text "user_message", null: false
    t.text "assistant_response"
    t.json "tools_used", default: []
    t.json "tool_results", default: []
    t.integer "token_count"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["conversation_id"], name: "index_chat_messages_on_conversation_id"
    t.index ["created_at"], name: "index_chat_messages_on_created_at"
    t.index ["firebase_uid", "conversation_id"], name: "index_chat_messages_on_firebase_uid_and_conversation_id"
    t.index ["firebase_uid"], name: "index_chat_messages_on_firebase_uid"
  end

  create_table "notification_logs", force: :cascade do |t|
    t.string "firebase_uid", null: false
    t.string "notification_type", null: false
    t.string "delivery_method"
    t.text "content"
    t.boolean "delivered", default: false
    t.datetime "delivered_at"
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_notification_logs_on_created_at"
    t.index ["firebase_uid", "notification_type"], name: "index_notification_logs_on_firebase_uid_and_notification_type"
    t.index ["firebase_uid"], name: "index_notification_logs_on_firebase_uid"
    t.index ["notification_type"], name: "index_notification_logs_on_notification_type"
  end

  create_table "user_preferences", force: :cascade do |t|
    t.string "firebase_uid", null: false
    t.boolean "daily_summary_enabled", default: true
    t.boolean "budget_alerts_enabled", default: true
    t.boolean "spending_reminders_enabled", default: true
    t.string "notification_time", default: "18:00"
    t.string "timezone", default: "UTC"
    t.json "delivery_methods", default: ["push"]
    t.integer "max_daily_messages", default: 50
    t.string "fcm_token"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["firebase_uid"], name: "index_user_preferences_on_firebase_uid", unique: true
  end
end
