# frozen_string_literal: true

# Service that orchestrates chat flow with Gemini AI and tool execution
class ChatOrchestratorService
  MAX_ITERATIONS = 5 # Prevent infinite loops

  def initialize(firebase_uid)
    @firebase_uid = firebase_uid
    @gemini = GeminiClientService.new
    @tools = FinancialToolsService.new(firebase_uid)
  end

  # Process a chat message and return AI response
  def process_message(user_message:, conversation_id:)
    # Load conversation context
    context = load_conversation_context(conversation_id)
    
    # Build messages array with system prompt
    messages = [
      { role: "system", content: GeminiClientService.system_prompt }
    ]
    
    # Add conversation history
    messages += context.map do |msg|
      [
        { role: "user", content: msg.user_message },
        { role: "assistant", content: msg.assistant_response }
      ]
    end.flatten.compact
    
    # Add new user message
    messages << { role: "user", content: user_message }

    # Execute conversation with function calling
    response_data = execute_with_tools(messages)

    # Save conversation to database
    chat_message = ChatMessage.create!(
      firebase_uid: @firebase_uid,
      conversation_id: conversation_id,
      user_message: user_message,
      assistant_response: response_data[:response],
      tools_used: response_data[:tools_used] || [],
      tool_results: response_data[:tool_results] || [],
      token_count: response_data[:token_count] || 0
    )

    {
      conversation_id: conversation_id,
      response: response_data[:response],
      tools_used: response_data[:tools_used] || [],
      timestamp: chat_message.created_at
    }
  rescue StandardError => e
    Rails.logger.error("Chat orchestrator error: #{e.message}\n#{e.backtrace.join("\n")}")
    {
      conversation_id: conversation_id,
      response: "I'm sorry, I encountered an error processing your request. Please try again.",
      error: e.message
    }
  end

  private

  def load_conversation_context(conversation_id, limit = 10)
    ChatMessage.conversation_context(conversation_id, limit)
  end

  def execute_with_tools(messages)
    iteration = 0
    tools_used = []
    tool_results = []
    total_tokens = 0

    loop do
      iteration += 1
      break if iteration > MAX_ITERATIONS

      # Call Gemini with tools
      result = @gemini.generate_content(
        messages: messages,
        tools: [GeminiClientService.tool_definitions]
      )

      # Track tokens
      total_tokens += result[:token_count] || 0

      # Check if AI wants to call functions
      if result[:function_calls].present?
        # Execute each function call
        result[:function_calls].each do |fc|
          function_name = fc[:name]
          arguments = fc[:arguments]

          Rails.logger.info("Executing function: #{function_name} with args: #{arguments.inspect}")

          # Execute the tool
          tool_result = execute_tool(function_name, arguments)
          tools_used << function_name
          tool_results << { function: function_name, result: tool_result }

          # Add function result to messages
          messages << {
            role: "function",
            name: function_name,
            content: tool_result.to_json
          }
        end

        # Continue loop to get AI's response based on function results
        next
      end

      # If no function calls, we have the final response
      if result[:text].present?
        return {
          response: result[:text],
          tools_used: tools_used,
          tool_results: tool_results,
          token_count: total_tokens
        }
      end

      # If we get here, something went wrong
      break
    end

    # Fallback response if loop exits abnormally
    {
      response: "I apologize, but I'm having trouble generating a response right now.",
      tools_used: tools_used,
      tool_results: tool_results,
      token_count: total_tokens
    }
  end

  def execute_tool(function_name, arguments)
    case function_name
    when "get_spending_summary"
      @tools.get_spending_summary(
        period: arguments["period"] || arguments[:period],
        category: arguments["category"] || arguments[:category]
      )
    when "get_budget_status"
      @tools.get_budget_status
    when "get_category_analysis"
      @tools.get_category_analysis(
        category: arguments["category"] || arguments[:category],
        period: arguments["period"] || arguments[:period]
      )
    when "get_transaction_list"
      @tools.get_transaction_list(
        filters: arguments["filters"] || arguments[:filters] || {}
      )
    when "get_spending_trends"
      @tools.get_spending_trends(
        months: (arguments["months"] || arguments[:months] || 6).to_i
      )
    when "compare_periods"
      @tools.compare_periods(
        period1: arguments["period1"] || arguments[:period1],
        period2: arguments["period2"] || arguments[:period2]
      )
    when "get_debt_status"
      @tools.get_debt_status
    when "get_savings_progress"
      @tools.get_savings_progress
    else
      { error: "Unknown function: #{function_name}" }
    end
  rescue StandardError => e
    Rails.logger.error("Tool execution error for #{function_name}: #{e.message}")
    { error: "Failed to execute #{function_name}: #{e.message}" }
  end
end
