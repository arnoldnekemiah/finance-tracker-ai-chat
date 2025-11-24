# frozen_string_literal: true

module Api
  module V1
    class NotificationsController < ApplicationController
      include FirebaseAuthConcern

      # GET /api/v1/notifications/preferences
      def show_preferences
        preferences = UserPreference.for_user(current_user_id)
        
        render json: {
          daily_summary_enabled: preferences.daily_summary_enabled,
          budget_alerts_enabled: preferences.budget_alerts_enabled,
          spending_reminders_enabled: preferences.spending_reminders_enabled,
          notification_time: preferences.notification_time,
          timezone: preferences.timezone,
          delivery_methods: preferences.delivery_methods,
          max_daily_messages: preferences.max_daily_messages,
          fcm_registered: preferences.fcm_registered?
        }, status: :ok
      rescue StandardError => e
        Rails.logger.error("Error fetching preferences: #{e.message}")
        render json: { error: "Failed to fetch preferences" }, status: :internal_server_error
      end

      # PUT /api/v1/notifications/preferences
      def update_preferences
        preferences = UserPreference.for_user(current_user_id)

        if preferences.update(preferences_params)
          render json: { message: "Preferences updated successfully" }, status: :ok
        else
          render json: { error: preferences.errors.full_messages }, status: :bad_request
        end
      rescue StandardError => e
        Rails.logger.error("Error updating preferences: #{e.message}")
        render json: { error: "Failed to update preferences" }, status: :internal_server_error
      end

      # POST /api/v1/webhooks/fcm_token
      def register_fcm_token
        token = params[:token]

        unless token.present?
          render json: { error: "FCM token is required" }, status: :bad_request
          return
        end

        preferences = UserPreference.for_user(current_user_id)
        
        if preferences.update(fcm_token: token)
          render json: { message: "FCM token registered successfully" }, status: :ok
        else
          render json: { error: preferences.errors.full_messages }, status: :bad_request
        end
      rescue StandardError => e
        Rails.logger.error("Error registering FCM token: #{e.message}")
        render json: { error: "Failed to register FCM token" }, status: :internal_server_error
      end

      private

      def preferences_params
        params.permit(
          :daily_summary_enabled,
          :budget_alerts_enabled,
          :spending_reminders_enabled,
          :notification_time,
          :timezone,
          :max_daily_messages,
          delivery_methods: []
        )
      end
    end
  end
end
