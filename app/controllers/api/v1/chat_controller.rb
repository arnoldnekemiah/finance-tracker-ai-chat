# frozen_string_literal: true

module Api
  module V1
    class ChatController < ApplicationController
      include FirebaseAuthConcern

      # POST /api/v1/chat/messages
      def create
        conversation_id = params[:conversation_id] || SecureRandom.uuid
        user_message = params[:message]

        unless user_message.present?
          render json: { error: "Message is required" }, status: :bad_request
          return
        end

        # Check rate limiting
        preferences = UserPreference.for_user(current_user_id)
        unless preferences.can_send_message?
          render json: { 
            error: "Daily message limit reached",
            limit: preferences.max_daily_messages
          }, status: :too_many_requests
          return
        end

        # Process message
        orchestrator = ChatOrchestratorService.new(current_user_id)
        result = orchestrator.process_message(
          user_message: user_message,
          conversation_id: conversation_id
        )

        render json: result, status: :ok
      rescue StandardError => e
        Rails.logger.error("Chat controller error: #{e.message}")
        render json: { error: "Failed to process message" }, status: :internal_server_error
      end

      # GET /api/v1/chat/conversations
      def index
        conversations = ChatMessage.for_user(current_user_id)
                                   .select(:conversation_id)
                                   .distinct
                                   .pluck(:conversation_id)

        conversation_list = conversations.map do |conv_id|
          last_message = ChatMessage.for_conversation(conv_id).last
          {
            id: conv_id,
            last_message: last_message&.user_message&.truncate(50),
            last_message_at: last_message&.created_at,
            message_count: ChatMessage.for_conversation(conv_id).count
          }
        end

        render json: { conversations: conversation_list }, status: :ok
      rescue StandardError => e
        Rails.logger.error("Error fetching conversations: #{e.message}")
        render json: { error: "Failed to fetch conversations" }, status: :internal_server_error
      end

      # GET /api/v1/chat/conversations/:id
      def show
        conversation_id = params[:id]
        messages = ChatMessage.for_conversation(conversation_id)

        # Verify user owns this conversation
        if messages.any? && messages.first.firebase_uid != current_user_id
          render json: { error: "Unauthorized" }, status: :forbidden
          return
        end

        formatted_messages = messages.map do |msg|
          {
            id: msg.id,
            user_message: msg.user_message,
            assistant_response: msg.assistant_response,
            tools_used: msg.tools_used,
            created_at: msg.created_at
          }
        end

        render json: {
          conversation_id: conversation_id,
          messages: formatted_messages
        }, status: :ok
      rescue StandardError => e
        Rails.logger.error("Error fetching conversation: #{e.message}")
        render json: { error: "Failed to fetch conversation" }, status: :internal_server_error
      end
    end
  end
end
