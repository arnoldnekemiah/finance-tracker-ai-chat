# frozen_string_literal: true

require "faraday"

# Service for sending push notifications via Firebase Cloud Messaging
class FcmService
  FCM_ENDPOINT = "https://fcm.googleapis.com/v1/projects"

  def initialize
    @project_id = Rails.application.credentials.dig(:firebase, :project_id)
    # TODO: Implement proper service account authentication
    # For now, this is a placeholder
  end

  # Send a push notification
  def send_notification(firebase_uid:, title:, body:, data: {})
    # Get user's FCM token
    preferences = UserPreference.find_by(firebase_uid: firebase_uid)
    
    unless preferences&.fcm_token.present?
      Rails.logger.warn("No FCM token for user #{firebase_uid}")
      return { success: false, error: "No FCM token registered" }
    end

    # Create notification log
    notification_log = NotificationLog.create!(
      firebase_uid: firebase_uid,
      notification_type: data[:notification_type] || "custom",
      delivery_method: "push",
      content: { title: title, body: body, data: data }.to_json
    )

    begin
      # Send to FCM
      result = send_to_fcm(preferences.fcm_token, title, body, data)
      
      if result[:success]
        notification_log.mark_as_delivered!
      else
        notification_log.mark_as_failed!(result[:error])
      end

      result
    rescue StandardError => e
      Rails.logger.error("FCM send error: #{e.message}")
      notification_log.mark_as_failed!(e.message)
      { success: false, error: e.message }
    end
  end

  # Send budget alert notification
  def send_budget_alert(firebase_uid:, category:, percentage:, spent:, limit:)
    title = "⚠️ Budget Alert"
    body = "You're at #{percentage}% of your #{category} budget ($#{spent}/$#{limit})"
    
    send_notification(
      firebase_uid: firebase_uid,
      title: title,
      body: body,
      data: {
        notification_type: "budget_alert",
        category: category,
        percentage: percentage
      }
    )
  end

  # Send daily summary notification
  def send_daily_summary(firebase_uid:, total_spent:, transaction_count:, largest_expense:)
    title = "📊 Today's Summary"
    body = "You spent $#{total_spent} today across #{transaction_count} transactions"
    
    if largest_expense
      body += ". Largest: $#{largest_expense[:amount]} at #{largest_expense[:merchant]}"
    end

    send_notification(
      firebase_uid: firebase_uid,
      title: title,
      body: body,
      data: {
        notification_type: "daily_summary",
        total_spent: total_spent,
        transaction_count: transaction_count
      }
    )
  end

  # Send spending reminder
  def send_spending_reminder(firebase_uid:)
    title = "💭 Spending Reminder"
    body = "You haven't logged any transactions recently. Don't forget to track your expenses!"

    send_notification(
      firebase_uid: firebase_uid,
      title: title,
      body: body,
      data: {
        notification_type: "spending_reminder"
      }
    )
  end

  private

  def send_to_fcm(token, title, body, data)
    # TODO: Implement actual FCM sending using Firebase Admin SDK
    # For development, just log the notification
    Rails.logger.info("FCM Notification: #{title} - #{body} to token #{token[0..10]}...")
    
    # Simulate success
    { success: true }
    
    # Production implementation would be:
    # message = {
    #   token: token,
    #   notification: {
    #     title: title,
    #     body: body
    #   },
    #   data: data.stringify_keys
    # }
    #
    # response = FCM.send_message(message)
    # { success: response.success? }
  rescue StandardError => e
    { success: false, error: e.message }
  end
end
