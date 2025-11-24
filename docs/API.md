# API Documentation

## Authentication

All endpoints require Firebase JWT authentication via the `Authorization` header.

```
Authorization: Bearer <firebase_id_token>
```

The `firebase_uid` is extracted from the token and used to scope all data access.

## Rate Limiting

- Default: 50 messages per user per day
- Configurable per user in `user_preferences`
- Returns `429 Too Many Requests` when exceeded

## Chat Endpoints

### POST /api/v1/chat/messages

Send a chat message and get AI response.

**Request:**
```json
{
  "message": "How much did I spend on dining this month?",
  "conversation_id": "uuid-optional"
}
```

**Response (200 OK):**
```json
{
  "conversation_id": "550e8400-e29b-41d4-a716-446655440000",
  "response": "You spent $487 on dining in November. This is 12% higher than October ($435). Your largest expense was $127 at Whole Foods.",
  "tools_used": ["get_spending_summary", "get_category_analysis"],
  "timestamp": "2025-11-22T17:30:00Z"
}
```

**Error Responses:**
- `400 Bad Request` - Message is missing
- `401 Unauthorized` - Invalid/missing Firebase token
- `429 Too Many Requests` - Daily message limit reached
- `500 Internal Server Error` - Processing failed

### GET /api/v1/chat/conversations

List all conversations for the authenticated user.

**Response (200 OK):**
```json
{
  "conversations": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "last_message": "How much did I spend on dining...",
      "last_message_at": "2025-11-22T17:30:00Z",
      "message_count": 8
    }
  ]
}
```

### GET /api/v1/chat/conversations/:id

Get all messages in a specific conversation.

**Response (200 OK):**
```json
{
  "conversation_id": "550e8400-e29b-41d4-a716-446655440000",
  "messages": [
    {
      "id": 1,
      "user_message": "How much did I spend this month?",
      "assistant_response": "You spent $2,340 in November...",
      "tools_used": ["get_spending_summary"],
      "created_at": "2025-11-22T17:30:00Z"
    }
  ]
}
```

**Error Responses:**
- `403 Forbidden` - Conversation belongs to another user

## Notification Endpoints

### GET /api/v1/notifications/preferences

Get user's notification preferences.

**Response (200 OK):**
```json
{
  "daily_summary_enabled": true,
  "budget_alerts_enabled": true,
  "spending_reminders_enabled": true,
  "notification_time": "18:00",
  "timezone": "America/New_York",
  "delivery_methods": ["push"],
  "max_daily_messages": 50,
  "fcm_registered": true
}
```

### PUT /api/v1/notifications/preferences

Update notification preferences.

**Request:**
```json
{
  "daily_summary_enabled": false,
  "budget_alerts_enabled": true,
  "notification_time": "20:00",
  "timezone": "America/Los_Angeles",
  "max_daily_messages": 30
}
```

**Response (200 OK):**
```json
{
  "message": "Preferences updated successfully"
}
```

**Error Responses:**
- `400 Bad Request` - Invalid parameters (e.g., bad timezone, invalid time format)

### POST /api/v1/webhooks/fcm_token

Register FCM device token for push notifications.

**Request:**
```json
{
  "token": "fcm_device_token_from_flutter_app"
}
```

**Response (200 OK):**
```json
{
  "message": "FCM token registered successfully"
}
```

## AI Tool Functions

The AI assistant has access to these tools:

### get_spending_summary
Get total spending for a period with category breakdown.

**Parameters:**
- `period` (required): "today", "this week", "this month", "last month", etc.
- `category` (optional): Filter by category

**Example Query:** "How much did I spend this month?"

### get_budget_status
Get budget utilization across all categories.

**Parameters:** None

**Example Query:** "Am I on track with my budget?"

### get_category_analysis
Deep dive into specific category spending.

**Parameters:**
- `category` (required): Category name
- `period` (required): Time period

**Example Query:** "Show me my dining expenses this month"

### get_transaction_list
Search and filter transactions.

**Parameters:**
- `filters` (object):
  - `start_date`: YYYY-MM-DD
  - `end_date`: YYYY-MM-DD
  - `category`: Category filter
  - `merchant`: Merchant name
  - `min_amount`: Minimum amount
  - `max_amount`: Maximum amount
  - `limit`: Max results (default 100)

**Example Query:** "Find all transactions over $100 last week"

### get_spending_trends
Analyze spending patterns over multiple months.

**Parameters:**
- `months` (optional): Number of months (default 6)

**Example Query:** "Show me my spending trends this year"

### compare_periods
Compare spending between two time periods.

**Parameters:**
- `period1` (required): First period
- `period2` (required): Second period

**Example Query:** "Compare my spending this month to last month"

### get_debt_status
Get debt balances and payment information.

**Parameters:** None

**Example Query:** "What's my debt status?"

### get_savings_progress
Check progress toward savings goals.

**Parameters:** None

**Example Query:** "How am I doing with my savings goals?"

## Webhook Endpoints

### POST /api/v1/webhooks/fcm_token
Register FCM device token (see above)

## Error Codes

| Code | Meaning |
|------|---------|
| 200  | Success |
| 400  | Bad Request - Invalid parameters |
| 401  | Unauthorized - Missing/invalid token |
| 403  | Forbidden - Access denied |
| 429  | Too Many Requests - Rate limit exceeded |
| 500  | Internal Server Error |

## Example Conversation Flow

1. User sends first message:
```
POST /api/v1/chat/messages
{
  "message": "How much did I spend on food?"
}
```

2. Backend creates conversation and returns response:
```json
{
  "conversation_id": "new-uuid",
  "response": "You spent $487 on food in November...",
  "tools_used": ["get_spending_summary"]
}
```

3. User follows up (using same conversation_id):
```
POST /api/v1/chat/messages
{
  "message": "What about dining out specifically?",
  "conversation_id": "new-uuid"
}
```

4. AI maintains context and responds:
```json
{
  "conversation_id": "new-uuid",
  "response": "Your dining out spending was $218, which is 45% of your total food budget...",
  "tools_used": ["get_category_analysis"]
}
```

## Testing with cURL

```bash
# Set your Firebase token
TOKEN="your_firebase_id_token"

# Send a chat message
curl -X POST http://localhost:3000/api/v1/chat/messages \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"message": "Show me my budget status"}'

# Get preferences
curl http://localhost:3000/api/v1/notifications/preferences \
  -H "Authorization: Bearer $TOKEN"

# Update preferences
curl -X PUT http://localhost:3000/api/v1/notifications/preferences \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"daily_summary_enabled": false}'
```
