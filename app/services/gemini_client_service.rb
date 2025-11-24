# frozen_string_literal: true

require "faraday"
require "json"

# Service for integrating with Google Gemini API
class GeminiClientService
  API_ENDPOINT = "https://generativelanguage.googleapis.com/v1beta/models"
  MODEL_NAME = "gemini-2.0-flash-exp"

  def initialize
    @api_key = Rails.application.credentials.dig(:gemini, :api_key)
    raise "Gemini API key not configured" unless @api_key

    @client = Faraday.new(url: API_ENDPOINT) do |f|
      f.request :json
      f.response :json
      f.adapter Faraday.default_adapter
    end
  end

  # Send a chat message with function calling
  def generate_content(messages:, tools: nil)
    url = "#{API_ENDPOINT}/#{MODEL_NAME}:generateContent?key=#{@api_key}"
    
    payload = {
      contents: format_messages(messages),
      generationConfig: {
        temperature: 0.7,
        topK: 40,
        topP: 0.95,
        maxOutputTokens: 2048
      }
    }

    # Add tools if provided
    payload[:tools] = tools if tools.present?

    response = @client.post(url, payload.to_json, { "Content-Type" => "application/json" })

    if response.success?
      parse_response(response.body)
    else
      Rails.logger.error("Gemini API error: #{response.status} - #{response.body}")
      { error: "Failed to generate response", status: response.status }
    end
  rescue StandardError => e
    Rails.logger.error("Gemini client error: #{e.message}")
    { error: e.message }
  end

  # Get tool definitions for function calling
  def self.tool_definitions
    {
      function_declarations: [
        {
          name: "get_spending_summary",
          description: "Get total spending for a specified period with breakdown by category. Use this when user asks about how much they spent.",
          parameters: {
            type: "object",
            properties: {
              period: {
                type: "string",
                description: "Time period: 'today', 'yesterday', 'this week', 'last week', 'this month', 'last month', 'this year', or custom 'YYYY-MM-DD to YYYY-MM-DD'"
              },
              category: {
                type: "string",
                description: "Optional: Filter by specific category (e.g., 'Dining', 'Transportation')"
              }
            },
            required: ["period"]
          }
        },
        {
          name: "get_budget_status",
          description: "Get current budget status showing how much has been spent vs budget limits for each category. Use when user asks about budget status or if they're on track.",
          parameters: {
            type: "object",
            properties: {}
          }
        },
        {
          name: "get_category_analysis",
          description: "Deep dive into spending for a specific category, including top merchants and transaction patterns.",
          parameters: {
            type: "object",
            properties: {
              category: {
                type: "string",
                description: "Category name to analyze"
              },
              period: {
                type: "string",
                description: "Time period to analyze"
              }
            },
            required: ["category", "period"]
          }
        },
        {
          name: "get_transaction_list",
          description: "Search and filter transactions by various criteria. Use when user wants to find specific transactions.",
          parameters: {
            type: "object",
            properties: {
              filters: {
                type: "object",
                properties: {
                  start_date: { type: "string", description: "Start date (YYYY-MM-DD)" },
                  end_date: { type: "string", description: "End date (YYYY-MM-DD)" },
                  category: { type: "string", description: "Category filter" },
                  merchant: { type: "string", description: "Merchant name filter" },
                  min_amount: { type: "number", description: "Minimum amount" },
                  max_amount: { type: "number", description: "Maximum amount" },
                  limit: { type: "integer", description: "Max results (default 100)" }
                }
              }
            }
          }
        },
        {
          name: "get_spending_trends",
          description: "Analyze spending patterns over multiple months to identify trends.",
          parameters: {
            type: "object",
            properties: {
              months: {
                type: "integer",
                description: "Number of months to analyze (default 6)"
              }
            }
          }
        },
        {
          name: "compare_periods",
          description: "Compare spending between two time periods.",
          parameters: {
            type: "object",
            properties: {
              period1: {
                type: "string",
                description: "First period to compare"
              },
              period2: {
                type: "string",
                description: "Second period to compare"
              }
            },
            required: ["period1", "period2"]
          }
        },
        {
          name: "get_debt_status",
          description: "Get information about user's debts, balances, and payment schedules.",
          parameters: {
            type: "object",
            properties: {}
          }
        },
        {
          name: "get_savings_progress",
          description: "Check progress toward savings goals.",
          parameters: {
            type: "object",
            properties: {}
          }
        }
      ]
    }
  end

  # System prompt for the AI
  def self.system_prompt
    <<~PROMPT
      You are Accountanta AI, a helpful and friendly financial assistant.
      
      Your role is to help users understand their spending, stay on budget, and make informed financial decisions.
      
      Guidelines:
      - Be concise and clear in your responses
      - Use the available tools to fetch real data from the user's financial records
      - Provide actionable insights, not just data
      - Be encouraging when users are doing well financially
      - Be constructive (not judgmental) when pointing out overspending
      - Use emojis tastefully to make responses more friendly (💰 📊 ⚠️ 🎯)
      - Format numbers as currency with $ sign
      - When showing percentages, round to 2 decimal places
      
      Available data:
      - Transactions (with date, amount, category, merchant)
      - Budgets (category limits and current spending)
      - Debts (balances, payments, due dates)
      - Savings goals (targets, progress, deadlines)
      
      Always use the tools to get accurate, up-to-date information rather than making assumptions.
    PROMPT
  end

  private

  def format_messages(messages)
    messages.map do |msg|
      if msg[:role] == "system"
        # Gemini doesn't have explicit system role, add to first user message
        next
      end

      {
        role: msg[:role] == "assistant" ? "model" : "user",
        parts: [{ text: msg[:content] }]
      }
    end.compact
  end

  def parse_response(body)
    candidates = body.dig("candidates")
    return { error: "No response generated" } unless candidates&.any?

    candidate = candidates.first
    content = candidate.dig("content", "parts")

    # Check for function calls
    function_calls = content&.select { |part| part.key?("functionCall") }
    
    if function_calls&.any?
      return {
        function_calls: function_calls.map do |fc|
          {
            name: fc.dig("functionCall", "name"),
            arguments: fc.dig("functionCall", "args") || {}
          }
        end
      }
    end

    # Extract text response
    text = content&.find { |part| part.key?("text") }&.dig("text")
    token_count = body.dig("usageMetadata", "totalTokenCount") || 0

    {
      text: text,
      token_count: token_count
    }
  end
end
