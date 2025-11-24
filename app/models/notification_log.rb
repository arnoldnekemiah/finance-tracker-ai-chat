class NotificationLog < ApplicationRecord
  validates :firebase_uid, presence: true
  validates :notification_type, presence: true

  # Notification types
  NOTIFICATION_TYPES = %w[
    daily_summary
    budget_alert
    spending_reminder
    custom_alert
  ].freeze

  validates :notification_type, inclusion: { in: NOTIFICATION_TYPES }

  # Scopes
  scope :for_user, ->(firebase_uid) { where(firebase_uid: firebase_uid) }
  scope :delivered, -> { where(delivered: true) }
  scope :failed, -> { where(delivered: false).where.not(error_message: nil) }
  scope :by_type, ->(type) { where(notification_type: type) }
  scope :recent, -> { order(created_at: :desc) }

  # Mark as delivered
  def mark_as_delivered!
    update!(delivered: true, delivered_at: Time.current)
  end

  # Mark as failed
  def mark_as_failed!(error)
    update!(delivered: false, error_message: error.to_s)
  end

  # Check delivery rate for a user
  def self.delivery_rate_for_user(firebase_uid, since: 1.week.ago)
    logs = for_user(firebase_uid).where("created_at >= ?", since)
    total = logs.count
    return 0 if total.zero?

    delivered_count = logs.delivered.count
    (delivered_count.to_f / total * 100).round(2)
  end
end
