# frozen_string_literal: true

# Background job for sending budget alert notifications
class BudgetAlertJob < ApplicationJob
  queue_as :default

  # Alert thresholds
  ALERT_THRESHOLDS = [80, 100, 110].freeze

  def perform
    Rails.logger.info("Starting BudgetAlertJob")

    # Get all users with budget alerts enabled
    users = UserPreference.where(budget_alerts_enabled: true)

    users.find_each do |preferences|
      process_user_budgets(preferences)
    rescue StandardError => e
      Rails.logger.error("Error processing budget alerts for user #{preferences.firebase_uid}: #{e.message}")
    end

    Rails.logger.info("Completed BudgetAlertJob")
  end

  private

  def process_user_budgets(preferences)
    firebase_uid = preferences.firebase_uid

    # Get budget status
    tools = FinancialToolsService.new(firebase_uid)
    budget_status = tools.get_budget_status

    # Check each category for alert thresholds
    budget_status[:by_category].each do |category_status|
      check_and_send_alert(firebase_uid, category_status)
    end
  end

  def check_and_send_alert(firebase_uid, category_status)
    percentage = category_status[:percentage]

    # Check if we should send an alert for this threshold
    ALERT_THRESHOLDS.each do |threshold|
      next unless percentage >= threshold && percentage < threshold + 5 # 5% window

      # Check if we already sent this alert recently (within last 24 hours)
      recent_alert = NotificationLog.for_user(firebase_uid)
                                   .by_type("budget_alert")
                                   .where("created_at >= ?", 24.hours.ago)
                                   .where("content LIKE ?", "%#{category_status[:category]}%#{threshold}%")
                                   .exists?

      next if recent_alert

      # Send alert
      fcm = FcmService.new
      fcm.send_budget_alert(
        firebase_uid: firebase_uid,
        category: category_status[:category],
        percentage: percentage.round(0),
        spent: category_status[:spent],
        limit: category_status[:limit]
      )

      break # Only send one alert per category
    end
  end
end
