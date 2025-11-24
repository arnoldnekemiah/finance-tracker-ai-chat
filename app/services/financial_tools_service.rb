# frozen_string_literal: true

# Service implementing AI tool functions for financial analysis
class FinancialToolsService
  def initialize(firebase_uid)
    @firebase_uid = firebase_uid
    @firebase = FirebaseService.instance
  end

  # Tool 1: Get spending summary
  def get_spending_summary(period:, category: nil)
    date_range = parse_period(period)
    filters = {
      start_date: date_range[:start],
      end_date: date_range[:end]
    }
    filters[:category] = category if category

    transactions = @firebase.get_transactions(@firebase_uid, filters)
    total = transactions.sum { |t| t[:amount]&.to_f || 0 }

    # Group by category
    by_category = transactions.group_by { |t| t[:category] }
                              .transform_values { |txns| txns.sum { |t| t[:amount]&.to_f || 0 }}
                              .sort_by { |_, amount| -amount }

    {
      period: period,
      total_spending: total.round(2),
      transaction_count: transactions.size,
      by_category: by_category.to_h,
      top_categories: by_category.first(3).to_h,
      largest_transaction: transactions.max_by { |t| t[:amount]&.to_f || 0 }
    }
  end

  # Tool 2: Get budget status
  def get_budget_status
    budgets = @firebase.get_budgets(@firebase_uid)
    current_month = Date.current.beginning_of_month

    transactions = @firebase.get_transactions(@firebase_uid, {
      start_date: current_month,
      end_date: Date.current
    })

    spending_by_category = transactions.group_by { |t| t[:category] }
                                      .transform_values { |txns| txns.sum { |t| t[:amount]&.to_f || 0 }}

    budget_status = budgets.map do |budget|
      category = budget[:category]
      limit = budget[:limit]&.to_f || 0
      spent = spending_by_category[category] || 0
      percentage = limit.zero? ? 0 : (spent / limit * 100).round(2)

      {
        category: category,
        limit: limit,
        spent: spent.round(2),
        remaining: (limit - spent).round(2),
        percentage: percentage,
        status: budget_status_label(percentage)
      }
    end

    total_budget = budgets.sum { |b| b[:limit]&.to_f || 0 }
    total_spent = spending_by_category.values.sum

    {
      overall: {
        total_budget: total_budget.round(2),
        total_spent: total_spent.round(2),
        percentage: total_budget.zero? ? 0 : (total_spent / total_budget * 100).round(2)
      },
      by_category: budget_status,
      over_budget: budget_status.select { |b| b[:percentage] > 100 },
      at_risk: budget_status.select { |b| b[:percentage] >= 80 && b[:percentage] <= 100 }
    }
  end

  # Tool 3: Get category analysis
  def get_category_analysis(category:, period:)
    date_range = parse_period(period)
    
    transactions = @firebase.get_transactions(@firebase_uid, {
      category: category,
      start_date: date_range[:start],
      end_date: date_range[:end]
    })

    total = transactions.sum { |t| t[:amount]&.to_f || 0 }
    avg_amount = transactions.empty? ? 0 : total / transactions.size

    # Top merchants
    by_merchant = transactions.group_by { |t| t[:merchant] || "Unknown" }
                              .transform_values { |txns| txns.sum { |t| t[:amount]&.to_f || 0 }}
                              .sort_by { |_, amount| -amount }

    {
      category: category,
      period: period,
      total_spending: total.round(2),
      transaction_count: transactions.size,
      average_transaction: avg_amount.round(2),
      top_merchants: by_merchant.first(5).to_h,
      largest_transaction: transactions.max_by { |t| t[:amount]&.to_f || 0 },
      smallest_transaction: transactions.min_by { |t| t[:amount]&.to_f || 0 }
    }
  end

  # Tool 4: Get transaction list
  def get_transaction_list(filters: {})
    parsed_filters = {}
    parsed_filters[:start_date] = Date.parse(filters[:start_date]) if filters[:start_date]
    parsed_filters[:end_date] = Date.parse(filters[:end_date]) if filters[:end_date]
    parsed_filters[:category] = filters[:category] if filters[:category]
    parsed_filters[:min_amount] = filters[:min_amount]&.to_f if filters[:min_amount]
    parsed_filters[:limit] = filters[:limit]&.to_i || 100

    transactions = @firebase.get_transactions(@firebase_uid, parsed_filters)

    # Apply additional filters not supported by Firestore query
    if filters[:max_amount]
      transactions = transactions.select { |t| (t[:amount]&.to_f || 0) <= filters[:max_amount].to_f }
    end

    if filters[:merchant]
      transactions = transactions.select { |t| t[:merchant]&.match?(/#{Regexp.escape(filters[:merchant])}/i) }
    end

    {
      count: transactions.size,
      transactions: transactions.take(100) # Limit to 100 for response size
    }
  end

  # Tool 5: Get spending trends
  def get_spending_trends(months: 6)
    start_date = months.months.ago.beginning_of_month
    transactions = @firebase.get_transactions(@firebase_uid, {
      start_date: start_date,
      end_date: Date.current
    })

    # Group by month
    by_month = transactions.group_by { |t| Date.parse(t[:date].to_s).beginning_of_month }
                          .transform_values { |txns| txns.sum { |t| t[:amount]&.to_f || 0 }}
                          .sort_by { |month, _| month }

    monthly_totals = by_month.values
    average_monthly = monthly_totals.empty? ? 0 : monthly_totals.sum / monthly_totals.size

    {
      period_months: months,
      monthly_spending: by_month.transform_values { |v| v.round(2) },
      average_monthly: average_monthly.round(2),
      highest_month: by_month.max_by { |_, amount| amount },
      lowest_month: by_month.min_by { |_, amount| amount },
      trend: calculate_trend(monthly_totals)
    }
  end

  # Tool 6: Compare periods
  def compare_periods(period1:, period2:)
    range1 = parse_period(period1)
    range2 = parse_period(period2)

    txns1 = @firebase.get_transactions(@firebase_uid, {
      start_date: range1[:start],
      end_date: range1[:end]
    })

    txns2 = @firebase.get_transactions(@firebase_uid, {
      start_date: range2[:start],
      end_date: range2[:end]
    })

    total1 = txns1.sum { |t| t[:amount]&.to_f || 0 }
    total2 = txns2.sum { |t| t[:amount]&.to_f || 0 }
    
    difference = total1 - total2
    percentage_change = total2.zero? ? 0 : ((difference / total2) * 100).round(2)

    {
      period1: { period: period1, total: total1.round(2), count: txns1.size },
      period2: { period: period2, total: total2.round(2), count: txns2.size },
      difference: difference.round(2),
      percentage_change: percentage_change,
      trend: difference > 0 ? "increased" : "decreased"
    }
  end

  # Tool 7: Get debt status
  def get_debt_status
    debts = @firebase.get_debts(@firebase_uid)
    
    total_debt = debts.sum { |d| d[:balance]&.to_f || 0 }
    total_monthly_payment = debts.sum { |d| d[:monthly_payment]&.to_f || 0 }

    debt_details = debts.map do |debt|
      {
        name: debt[:name],
        balance: debt[:balance]&.to_f&.round(2),
        monthly_payment: debt[:monthly_payment]&.to_f&.round(2),
        interest_rate: debt[:interest_rate]&.to_f,
        due_date: debt[:due_date]
      }
    end

    {
      total_debt: total_debt.round(2),
      total_monthly_payment: total_monthly_payment.round(2),
      debt_count: debts.size,
      debts: debt_details
    }
  end

  # Tool 8: Get savings progress
  def get_savings_progress
    goals = @firebase.get_savings_goals(@firebase_uid)

    goal_progress = goals.map do |goal|
      target = goal[:target_amount]&.to_f || 0
      current = goal[:current_amount]&.to_f || 0
      percentage = target.zero? ? 0 : (current / target * 100).round(2)

      {
        name: goal[:name],
        target_amount: target.round(2),
        current_amount: current.round(2),
        remaining: (target - current).round(2),
        percentage: percentage,
        deadline: goal[:deadline],
        status: savings_status_label(percentage)
      }
    end

    total_target = goals.sum { |g| g[:target_amount]&.to_f || 0 }
    total_saved = goals.sum { |g| g[:current_amount]&.to_f || 0 }

    {
      overall: {
        total_target: total_target.round(2),
        total_saved: total_saved.round(2),
        percentage: total_target.zero? ? 0 : (total_saved / total_target * 100).round(2)
      },
      goals: goal_progress
    }
  end

  private

  def parse_period(period)
    case period.downcase
    when "today"
      { start: Date.current, end: Date.current }
    when "yesterday"
      { start: Date.yesterday, end: Date.yesterday }
    when "this week"
      { start: Date.current.beginning_of_week, end: Date.current }
    when "last week"
      { start: 1.week.ago.beginning_of_week, end: 1.week.ago.end_of_week }
    when "this month"
      { start: Date.current.beginning_of_month, end: Date.current }
    when "last month"
      { start: 1.month.ago.beginning_of_month, end: 1.month.ago.end_of_month }
    when "this year"
      { start: Date.current.beginning_of_year, end: Date.current }
    when "last year"
      { start: 1.year.ago.beginning_of_year, end: 1.year.ago.end_of_year }
    else
      # Try parsing as date range "YYYY-MM-DD to YYYY-MM-DD"
      if period.include?("to")
        dates = period.split("to").map { |d| Date.parse(d.strip) }
        { start: dates[0], end: dates[1] }
      else
        { start: Date.current.beginning_of_month, end: Date.current }
      end
    end
  end

  def budget_status_label(percentage)
    case percentage
    when 0...50 then "on_track"
    when 50...80 then "moderate"
    when 80...100 then "at_risk"
    when 100...110 then "over_budget"
    else "significantly_over"
    end
  end

  def savings_status_label(percentage)
    case percentage
    when 0...25 then "just_started"
    when 25...50 then "making_progress"
    when 50...75 then "halfway_there"
    when 75...100 then "almost_complete"
    else "goal_achieved"
    end
  end

  def calculate_trend(values)
    return "stable" if values.size < 2
    
    recent = values.last(3).sum / [values.last(3).size, 1].max
    older = values.first(3).sum / [values.first(3).size, 1].max
    
    diff_percentage = older.zero? ? 0 : ((recent - older) / older * 100)
    
    case diff_percentage
    when -Float::INFINITY..-10 then "decreasing"
    when -10..10 then "stable"
    else "increasing"
    end
  end
end
