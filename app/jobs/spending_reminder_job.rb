# frozen_string_literal: true

# Background job for sending spending reminders
class SpendingReminderJob < ApplicationJob
  queue_as :default

  # Only remind if no transactions in this many days
  REMINDER_THRESHOLD_DAYS = 2
  
  # Don't remind more often than this
  MIN_REMINDER_FREQUENCY_DAYS = 3

  def perform
    Rails.logger.info("Starting SpendingReminderJob")

    # Get all users with spending reminders enabled
    users = UserPreference.where(spending_reminders_enabled: true)

    users.find_each do |preferences|
      process_user_reminder(preferences)
    rescue StandardError => e
      Rails.logger.error("Error processing spending reminder for user #{preferences.firebase_uid}: #{e.message}")
    end

    Rails.logger.info("Completed SpendingReminderJob")
  end

  private

  def process_user_reminder(preferences)
    firebase_uid = preferences.firebase_uid

    # Check if we sent a reminder recently
    recent_reminder = NotificationLog.for_user(firebase_uid)
                                    .by_type("spending_reminder")
                                    .where("created_at >= ?", MIN_REMINDER_FREQUENCY_DAYS.days.ago)
                                    .exists?

    return if recent_reminder

    # Check if user has recent transactions
    tools = FinancialToolsService.new(firebase_uid)
    recent_txns = tools.get_transaction_list(
      filters: {
        start_date: REMINDER_THRESHOLD_DAYS.days.ago.to_date.to_s,
        end_date: Date.current.to_s
      }
    )

    # Only send reminder if no recent transactions
    return if recent_txns[:count] > 0

    # Send reminder
    fcm = FcmService.new
    fcm.send_spending_reminder(firebase_uid: firebase_uid)
  end
end
