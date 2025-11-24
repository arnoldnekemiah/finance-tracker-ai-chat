class UserPreference < ApplicationRecord
  validates :firebase_uid, presence: true, uniqueness: true
  validates :timezone, presence: true
  validates :notification_time, format: { with: /\A\d{2}:\d{2}\z/, message: "must be in HH:MM format" }
  validates :max_daily_messages, numericality: { greater_than: 0, less_than_or_equal_to: 100 }

  # Ensure delivery_methods is always an array
  attribute :delivery_methods, :string, array: true, default: ["push"]

  # Find or create preferences for a user
  def self.for_user(firebase_uid)
    find_or_create_by(firebase_uid: firebase_uid)
  end

  # Check if user can send more messages today
  def can_send_message?
    return false unless daily_summary_enabled || budget_alerts_enabled || spending_reminders_enabled

    messages_today = ChatMessage.for_user(firebase_uid)
                                 .where("created_at >= ?", Time.current.beginning_of_day)
                                 .count

    messages_today < max_daily_messages
  end

  # Get notification time in user's timezone
  def notification_time_in_timezone
    Time.use_zone(timezone) do
      Time.current.change(
        hour: notification_time.split(":")[0].to_i,
        min: notification_time.split(":")[1].to_i
      )
    end
  end

  # Check if FCM token is registered
  def fcm_registered?
    fcm_token.present?
  end
end
