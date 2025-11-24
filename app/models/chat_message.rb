class ChatMessage < ApplicationRecord
  validates :firebase_uid, presence: true
  validates :conversation_id, presence: true
  validates :user_message, presence: true

  # Scopes
  scope :for_user, ->(firebase_uid) { where(firebase_uid: firebase_uid) }
  scope :for_conversation, ->(conversation_id) { where(conversation_id: conversation_id).order(:created_at) }
  scope :recent, -> { order(created_at: :desc) }

  # Get conversation context (last N messages)
  def self.conversation_context(conversation_id, limit = 10)
    for_conversation(conversation_id).last(limit)
  end

  # Calculate total tokens used by user
  def self.total_tokens_for_user(firebase_uid, since: 1.day.ago)
    for_user(firebase_uid)
      .where("created_at >= ?", since)
      .sum(:token_count) || 0
  end

  # Cost estimation (assuming ~$0.10 per 1M tokens)
  def estimated_cost
    return 0 unless token_count.present?
    (token_count / 1_000_000.0) * 0.10
  end

  def self.estimated_cost_for_user(firebase_uid, since: 1.month.ago)
    total_tokens = total_tokens_for_user(firebase_uid, since: since)
    (total_tokens / 1_000_000.0) * 0.10
  end
end
