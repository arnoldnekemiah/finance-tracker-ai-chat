class CreateUserPreferences < ActiveRecord::Migration[8.0]
  def change
    create_table :user_preferences do |t|
      t.string :firebase_uid, null: false
      t.boolean :daily_summary_enabled, default: true
      t.boolean :budget_alerts_enabled, default: true
      t.boolean :spending_reminders_enabled, default: true
      t.string :notification_time, default: "18:00"
      t.string :timezone, default: "UTC"
      t.json :delivery_methods, default: ["push"]
      t.integer :max_daily_messages, default: 50
      t.string :fcm_token
      t.timestamps
    end

    add_index :user_preferences, :firebase_uid, unique: true
  end
end
