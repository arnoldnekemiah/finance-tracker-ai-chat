class CreateNotificationLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :notification_logs do |t|
      t.string :firebase_uid, null: false
      t.string :notification_type, null: false
      t.string :delivery_method
      t.text :content
      t.boolean :delivered, default: false
      t.datetime :delivered_at
      t.text :error_message
      t.timestamps
    end

    add_index :notification_logs, :firebase_uid
    add_index :notification_logs, :notification_type
    add_index :notification_logs, :created_at
    add_index :notification_logs, [:firebase_uid, :notification_type]
  end
end
