# frozen_string_literal: true

# Controller concern for Firebase authentication
module FirebaseAuthConcern
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_firebase_user!
  end

  private

  def authenticate_firebase_user!
    token = extract_token_from_header
    
    unless token
      render json: { error: "Authorization header missing" }, status: :unauthorized
      return
    end

    @current_user_id = verify_firebase_token(token)
    
    unless @current_user_id
      render json: { error: "Invalid or expired token" }, status: :unauthorized
    end
  rescue StandardError => e
    Rails.logger.error("Authentication error: #{e.message}")
    render json: { error: "Authentication failed" }, status: :unauthorized
  end

  def extract_token_from_header
    auth_header = request.headers["Authorization"]
    return nil unless auth_header&.start_with?("Bearer ")
    
    auth_header.split(" ").last
  end

  def verify_firebase_token(token)
    # Decode JWT token
    decoded_token = JWT.decode(token, nil, false)
    payload = decoded_token.first

    # Extract firebase_uid (usually in 'sub' claim)
    firebase_uid = payload["sub"] || payload["user_id"]
    
    # TODO: In production, verify token signature with Firebase public keys
    # For now, we'll trust tokens for development
    # See: https://firebase.google.com/docs/auth/admin/verify-id-tokens
    
    firebase_uid
  rescue JWT::DecodeError => e
    Rails.logger.error("JWT decode error: #{e.message}")
    nil
  end

  attr_reader :current_user_id
end
