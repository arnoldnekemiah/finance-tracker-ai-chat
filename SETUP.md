# Accountanta AI Chat - Setup Guide

## Quick Start

Follow these steps to get the Accountanta AI Chat backend running locally.

### Step 1: Configure Firebase Credentials

1. Run the credentials editor:
```bash
EDITOR="nano" bin/rails credentials:edit
```

2. Add the following content:
```yaml
gemini:
  api_key: AIzaSyCMmDYunEKrpMichbMYQCet5QnRQUyFF8M

firebase:
  project_id: YOUR_FIREBASE_PROJECT_ID
```

3. Save and exit (Ctrl+O, Enter, Ctrl+X in nano)

### Step 2: Firebase Service Account

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Go to Project Settings > Service Accounts
4. Click "Generate new private key"
5. Save the JSON file as `config/firebase_credentials.json`

**IMPORTANT**: Add this to `.gitignore`:
```bash
echo "config/firebase_credentials.json" >> .gitignore
```

### Step 3: Firestore Setup

Your Firestore should have this structure:

```
users (collection)
  └── {firebase_uid} (document)
      ├── transactions (subcollection)
      │   └── {docId}
      │       ├── date: "2025-11-22"
      │       ├── amount: 45.50
      │       ├── category: "Dining"
      │       ├── merchant: "Chipotle"
      │
      ├── budgets (subcollection)
      │   └── {docId}
      │       ├── category: "Dining"
      │       ├── limit: 300
      │
      ├── debts (subcollection)
      │   └── {docId}
      │       ├── name: "Credit Card"
      │       ├── balance: 5000
      │       ├── monthly_payment: 250
      │       ├── interest_rate: 18.5
      │
      └── savingGoals (subcollection)
          └── {docId}
              ├── name: "Emergency Fund"
              ├── target_amount: 10000
              ├── current_amount: 2500
              ├── deadline: "2026-12-31"
```

### Step 4: Test Firebase Connection

```bash
bin/rails console
```

In the console:
```ruby
# Test Firebase connection
firebase = FirebaseService.instance
firebase.firestore # Should not be nil

# Test fetching transactions (replace with actual firebase_uid)
firebase.get_transactions("test_user_id")
```

### Step 5: Test Gemini API

```ruby
# In rails console
gemini = GeminiClientService.new
result = gemini.generate_content(
  messages: [{ role: "user", content: "Hello!" }]
)
puts result[:text]
```

### Step 6: Start the Servers

Terminal 1 (Rails API):
```bash
bin/rails server
```

Terminal 2 (Background Jobs):
```bash
bin/jobs
```

## Testing the Chat API

### Option 1: Using curl (requires Firebase token)

You'll need a Firebase ID token from your Flutter app or Firebase Auth.

```bash
# Get a token from Firebase Auth
# Then use it in requests:

curl -X POST http://localhost:3000/api/v1/chat/messages \
  -H "Authorization: Bearer YOUR_FIREBASE_ID_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "How much did I spend this month?",
    "conversation_id": "test-conversation-123"
  }'
```

### Option 2: Bypass Auth for Testing (Development Only)

Temporarily comment out authentication in the controller:

```ruby
# app/controllers/api/v1/chat_controller.rb
class Api::V1::ChatController < ApplicationController
  # include FirebaseAuthConcern  # COMMENT THIS OUT FOR TESTING
  
  def create
    @current_user_id = "test_user_id"  # ADD THIS
    # ... rest of code
```

Then test without auth:
```bash
curl -X POST http://localhost:3000/api/v1/chat/messages \
  -H "Content-Type: application/json" \
  -d '{
    "message": "What is my budget status?"
  }'
```

## Common Issues

### Issue: "Firebase credentials not found"

**Solution**: Make sure `config/firebase_credentials.json` exists and is valid JSON.

### Issue: "Gemini API key not configured"

**Solution**: Run `EDITOR="nano" bin/rails credentials:edit` and add the Gemini API key.

### Issue: Background jobs not running

**Solution**: Make sure you're running `bin/jobs` in a separate terminal.

### Issue: Firestore returns empty arrays

**Solution**: 
1. Check that your Firebase project ID is correct in credentials
2. Verify the Firestore structure matches the expected schema
3. Check that the firebase_uid you're testing with actually has data

### Issue: "Database does not exist"

**Solution**: Run `bin/rails db:create db:migrate`

## Next Steps

Once the backend is running:

1. **Create a test user in Firebase**
2. **Add sample transactions to Firestore**
3. **Test the chat API with real queries**
4. **Integrate with Flutter app** (see Flutter integration guide)
5. **Set up FCM for notifications**

## Production Deployment Checklist

Before deploying to production:

- [ ] Secure Firebase credentials (use environment variables or secrets manager)
- [ ] Implement proper Firebase token verification (see `firebase_auth_concern.rb` TODO)
- [ ] Update CORS origins to specific Flutter app domain
- [ ] Implement actual FCM sending (not just logging)
- [ ] Set up error monitoring (Sentry, Rollbar, etc.)
- [ ] Configure database backups
- [ ] Set up SSL/TLS certificates
- [ ] Review and tighten rate limits
- [ ] Enable production logging
- [ ] Test all notification jobs in staging
