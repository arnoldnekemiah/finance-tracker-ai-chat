class CreateChatMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :chat_messages do |t|
      t.string :firebase_uid, null: false
      t.string :conversation_id, null: false
      t.text :user_message, null: false
      t.text :assistant_response
      t.json :tools_used, default: []
      t.json :tool_results, default: []
      t.integer :token_count
      t.timestamps
    end

    add_index :chat_messages, :firebase_uid
    add_index :chat_messages, :conversation_id
    add_index :chat_messages, [:firebase_uid, :conversation_id]
    add_index :chat_messages, :created_at
  end
end
