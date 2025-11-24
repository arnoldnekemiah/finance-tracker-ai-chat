# Accountanta AI Chat Backend

AI-powered financial assistant API for the Accountanta finance tracker app. Built with Rails 8.0, Google Gemini AI, and Firebase.

## Features

- 🤖 **Natural Language Chat**: Conversational AI assistant powered by Google Gemini
- 📊 **Financial Insights**: 8 AI tool functions for spending analysis, budget tracking, and financial planning
- 🔔 **Smart Notifications**: Automated budget alerts, daily summaries, and spending reminders
- 🔐 **Firebase Authentication**: Secure user authentication via Firebase ID tokens
- ☁️ **Firestore Integration**: Real-time access to user financial data

## Tech Stack

- **Framework**: Ruby on Rails 8.0 (API mode)
- **Database**: PostgreSQL 15+
- **Background Jobs**: Solid Queue (Rails 8 built-in)
- **AI**: Google Gemini 2.0 Flash
- **Firebase**: Authentication, Firestore, Cloud Messaging (FCM)
- **Authentication**: JWT via Firebase ID tokens

## Prerequisites

- Ruby 3.3.1
- PostgreSQL 15+
- Firebase project with Firestore and Authentication enabled
- Google Gemini API key

## Installation

### 1. Clone and Install Dependencies

```bash
git clone <repository-url>
cd finance-tracker-ai-chat
bundle install
```

### 2. Database Setup

```bash
bin/rails db:create
bin/rails db:migrate
```

### 3. Firebase Configuration

1. Create a Firebase project at https://console.firebase.google.com
2. Enable Authentication and Firestore
3. Download service account JSON from Project Settings > Service Accounts
4. Save as `config/firebase_credentials.json`
5. **Add to .gitignore to prevent committing**

### 4. Configure Credentials

Edit Rails encrypted credentials:

```bash
EDITOR="nano" bin/rails credentials:edit
```

Add the following:

```yaml
gemini:
  api_key: YOUR_GEMINI_API_KEY_HERE

firebase:
  project_id: your-firebase-project-id
```

Save and exit.

### 5. Environment Setup

The Gemini API key provided in the PRD:
```
AIzaSyCMmDYunEKrpMichbMYQCet5QnRQUyFF8M
```

Add this to your credentials file in the `gemini.api_key` field.

## Running the Application

### Start Rails Server

```bash
bin/rails server
```

API will be available at `http://localhost:3000`

### Start Background Jobs

In a separate terminal:

```bash
bin/jobs
```

This starts Solid Queue workers for processing notifications.

## API Endpoints

### Chat Endpoints

**Send Chat Message**
```http
POST /api/v1/chat/messages
Authorization: Bearer <firebase_id_token>
Content-Type: application/json

{
  "message": "How much did I spend this month?",
  "conversation_id": "optional-uuid"
}
```

**List Conversations**
```http
GET /api/v1/chat/conversations
Authorization: Bearer <firebase_id_token>
```

**Get Conversation Details**
```http
GET /api/v1/chat/conversations/:id
Authorization: Bearer <firebase_id_token>
```

### Notification Endpoints

**Get Preferences**
```http
GET /api/v1/notifications/preferences
Authorization: Bearer <firebase_id_token>
```

**Update Preferences**
```http
PUT /api/v1/notifications/preferences
Authorization: Bearer <firebase_id_token>
Content-Type: application/json

{
  "daily_summary_enabled": true,
  "budget_alerts_enabled": true,
  "notification_time": "18:00",
  "timezone": "America/New_York"
}
```

**Register FCM Token**
```http
POST /api/v1/webhooks/fcm_token
Authorization: Bearer <firebase_id_token>
Content-Type: application/json

{
  "token": "fcm_device_token_from_flutter_app"
}
```

## AI Tool Functions

The assistant has access to 8 financial analysis tools:

1. **get_spending_summary** - Total spending by period and category
2. **get_budget_status** - Budget utilization across categories
3. **get_category_analysis** - Deep dive into category spending
4. **get_transaction_list** - Search/filter transactions
5. **get_spending_trends** - Monthly spending patterns
6. **compare_periods** - Period-over-period comparison
7. **get_debt_status** - Debt tracking and payment schedules
8. **get_savings_progress** - Savings goal monitoring

## Background Jobs

### Daily Summary Job
- **Schedule**: Every hour (checks user timezone)
- **Function**: Sends spending summary at user's preferred time
- **Format**: "📊 You spent $X today across Y transactions"

### Budget Alert Job
- **Schedule**: Every 2 hours
- **Triggers**: 80%, 100%, 110% of budget
- **Deduplication**: Won't send same alert within 24h

### Spending Reminder Job
- **Schedule**: Daily at 8 PM UTC
- **Condition**: No transactions logged in 2+ days
- **Frequency**: Max once per 3 days

## Firestore Expected Schema

The app expects Firestore collections structured as:

```
users/{userId}/
  ├── transactions/
  │   └── {transactionId}
  │       ├── date: timestamp
  │       ├── amount: number
  │       ├── category: string
  │       └── merchant: string
  ├── budgets/
  │   └── {budgetId}
  │       ├── category: string
  │       └── limit: number
  ├── debts/
  │   └── {debtId}
  │       ├── name: string
  │       ├── balance: number
  │       ├── monthly_payment: number
  │       └── interest_rate: number
  └── savingGoals/
      └── {goalId}
          ├── name: string
          ├── target_amount: number
          ├── current_amount: number
          └── deadline: timestamp
```

## Testing Chat Locally

You can test the chat API using curl (replace TOKEN with a Firebase ID token):

```bash
curl -X POST http://localhost:3000/api/v1/chat/messages \
  -H "Authorization: Bearer YOUR_FIREBASE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"message": "How much did I spend this month?"}'
```

## Development Notes

### Firebase Token Verification

Currently using basic JWT decode for development. **Production deployment should verify tokens with Firebase public keys**. See `app/controllers/concerns/firebase_auth_concern.rb` for TODO.

### FCM Implementation

FCM service currently logs notifications instead of sending. Implement actual FCM sending in `app/services/fcm_service.rb` using Firebase Admin SDK.

### Rate Limiting

Basic rate limiting implemented in controller. For production, add Redis-based middleware for better rate limiting and abuse prevention.

## Architecture

```
┌─────────────────┐
│  Flutter App    │
└────────┬────────┘
         │ (Firebase ID Token)
         ↓
┌─────────────────────────────────┐
│   Rails API Server              │
├─────────────────────────────────┤
│ • ChatController                │
│ • NotificationsController       │
│ • FirebaseAuthConcern           │
└────────┬────────────────────────┘
         │
    ┌────┴────┐
    ↓         ↓
┌──────┐  ┌──────────────────┐
│  DB  │  │ Background Jobs  │
│ PG   │  │ (Solid Queue)    │
└──────┘  └──────────────────┘
    │              │
    ↓              ↓
┌─────────────────────────────┐
│  External Services          │
├─────────────────────────────┤
│ • Google Gemini API         │
│ • Firebase Firestore        │
│ • Firebase Cloud Messaging  │
└─────────────────────────────┘
```

## Monitoring

### Check Background Job Status

```bash
bin/rails console
> SolidQueue::Job.last(10)
```

### View Chat Messages

```bash
bin/rails console
> ChatMessage.last(5)
```

### Check Notification Delivery

```bash
bin/rails console
> NotificationLog.delivery_rate_for_user("firebase_uid")
```

## Deployment

For production deployment:

1. ✅ Set up PostgreSQL database
2. ✅ Configure Firebase credentials securely
3. ✅ Add Gemini API key to credentials
4. ⚠️ Implement proper Firebase token verification
5. ⚠️ Implement actual FCM sending (not just logging)
6. ⚠️ Set up error monitoring (Sentry/Rollbar)
7. ⚠️ Configure CORS for production domain
8. ✅ Run migrations
9. ✅ Start Solid Queue workers

## License

[Your License Here]
