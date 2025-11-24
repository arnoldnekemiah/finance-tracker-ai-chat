# frozen_string_literal: true

# Initialize Firebase Admin SDK
begin
  FirebaseService.instance
  Rails.logger.info("Firebase initialization completed during boot")
rescue StandardError => e
  Rails.logger.error("Firebase initialization failed during boot: #{e.message}")
end
