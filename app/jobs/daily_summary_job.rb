# frozen_string_literal: true

# Background job for sending daily spending summaries
class DailySummaryJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info("Starting DailySummaryJob")

    # Get all users with daily summary enabled
    users = UserPreference.where(daily_summary_enabled: true)

    users.find_each do |preferences|
      process_user_summary(preferences)
    rescue StandardError => e
      Rails.logger.error("Error processing daily summary for user #{preferences.firebase_uid}: #{e.message}")
    end

    Rails.logger.info("Completed DailySummaryJob")
  end

  private

  def process_user_summary(preferences)
    firebase_uid = preferences.firebase_uid

    # Check if it's the right time to send (based on user's timezone and preferred time)
    unless should_send_now?(preferences)
      return
    end

    # Get today's transactions
    tools = FinancialToolsService.new(firebase_uid)
    summary = tools.get_spending_summary(period: "today")

    # Skip if no spending today
    return if summary[:total_spending].zero?

    # Send notification
    fcm = FcmService.new
    fcm.send_daily_summary(
      firebase_uid: firebase_uid,
      total_spent: summary[:total_spending],
      transaction_count: summary[:transaction_count],
      largest_expense: summary[:largest_transaction]
    )
  end

  def should_send_now?(preferences)
    # Get current time in user's timezone
    user_time = Time.use_zone(preferences.timezone) { Time.current }
    notification_hour, notification_minute = preferences.notification_time.split(":").map(&:to_i)

    # Check if current hour matches notification time (with 1-hour window)
    user_time.hour == notification_hour
  end
end
