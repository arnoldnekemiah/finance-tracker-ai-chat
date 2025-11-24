# frozen_string_literal: true

# Firebase service for accessing Firestore data
# Singleton pattern to ensure single Firebase client instance
class FirebaseService
  include Singleton

  attr_reader :firestore

  def initialize
    @firestore = nil
    initialize_firebase
  end

  # Fetch transactions for a user
  def get_transactions(firebase_uid, filters = {})
    return [] unless @firestore

    collection_ref = @firestore.col("users/#{firebase_uid}/transactions")

    # Apply filters
    if filters[:start_date]
      collection_ref = collection_ref.where("date", ">=", filters[:start_date])
    end

    if filters[:end_date]
      collection_ref = collection_ref.where("date", "<=", filters[:end_date])
    end

    if filters[:category]
      collection_ref = collection_ref.where("category", "==", filters[:category])
    end

    if filters[:min_amount]
      collection_ref = collection_ref.where("amount", ">=", filters[:min_amount])
    end

    if filters[:limit]
      collection_ref = collection_ref.limit(filters[:limit])
    end

    # Execute query and convert to array of hashes
    collection_ref.get.map { |doc| doc.data.merge(id: doc.document_id) }
  rescue StandardError => e
    Rails.logger.error("Firebase error fetching transactions: #{e.message}")
    []
  end

  # Fetch budgets for a user
  def get_budgets(firebase_uid)
    return [] unless @firestore

    @firestore.col("users/#{firebase_uid}/budgets")
              .get
              .map { |doc| doc.data.merge(id: doc.document_id) }
  rescue StandardError => e
    Rails.logger.error("Firebase error fetching budgets: #{e.message}")
    []
  end

  # Fetch debts for a user
  def get_debts(firebase_uid)
    return [] unless @firestore

    @firestore.col("users/#{firebase_uid}/debts")
              .get
              .map { |doc| doc.data.merge(id: doc.document_id) }
  rescue StandardError => e
    Rails.logger.error("Firebase error fetching debts: #{e.message}")
    []
  end

  # Fetch savings goals for a user
  def get_savings_goals(firebase_uid)
    return [] unless @firestore

    @firestore.col("users/#{firebase_uid}/savingGoals")
              .get
              .map { |doc| doc.data.merge(id: doc.document_id) }
  rescue StandardError => e
    Rails.logger.error("Firebase error fetching savings goals: #{e.message}")
    []
  end

  # Fetch categories for a user
  def get_categories(firebase_uid)
    return [] unless @firestore

    @firestore.col("users/#{firebase_uid}/categories")
              .get
              .map { |doc| doc.data.merge(id: doc.document_id) }
  rescue StandardError => e
    Rails.logger.error("Firebase error fetching categories: #{e.message}")
    []
  end

  # Get user profile
  def get_user_profile(firebase_uid)
    return nil unless @firestore

    doc_ref = @firestore.doc("users/#{firebase_uid}")
    doc = doc_ref.get
    doc.exists? ? doc.data : nil
  rescue StandardError => e
    Rails.logger.error("Firebase error fetching user profile: #{e.message}")
    nil
  end

  private

  def initialize_firebase
    require "google/cloud/firestore"

    # Check if credentials are configured
    credentials_path = Rails.root.join("config", "firebase_credentials.json")

    if File.exist?(credentials_path)
      @firestore = Google::Cloud::Firestore.new(
        project_id: Rails.application.credentials.dig(:firebase, :project_id),
        credentials: credentials_path.to_s
      )
      Rails.logger.info("Firebase Firestore initialized successfully")
    else
      Rails.logger.warn("Firebase credentials not found at #{credentials_path}. Firebase features will be disabled.")
    end
  rescue StandardError => e
    Rails.logger.error("Failed to initialize Firebase: #{e.message}")
    @firestore = nil
  end
end
