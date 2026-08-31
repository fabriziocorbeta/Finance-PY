class Budget < ApplicationRecord
  include Monetizable

  PARAM_DATE_FORMAT = "%b-%Y"

  attr_accessor :current_user

  belongs_to :family

  has_many :budget_categories, -> { includes(:category) }, dependent: :destroy

  validates :start_date, :end_date, presence: true
  validates :start_date, :end_date, uniqueness: { scope: :family_id }

  monetize :budgeted_spending, :expected_income, :allocated_spending,
           :actual_spending, :available_to_spend, :available_to_allocate,
           :estimated_spending, :estimated_income, :actual_income, :remaining_expected_income,
           :precomputed_estimated_spending

  class << self
    def date_to_param(date)
      date.strftime(PARAM_DATE_FORMAT).downcase
    end

    def param_to_date(param, family: nil)
      base_date = Date.strptime(param, PARAM_DATE_FORMAT)
      if family&.uses_custom_month_start?
        Date.new(base_date.year, base_date.month, family.month_start_day)
      else
        base_date.beginning_of_month
      end
    end

    def budget_date_valid?(date, family:)
      budget_start = if family.uses_custom_month_start?
        family.custom_month_start_for(date)
      else
        date.beginning_of_month
      end

      budget_start >= oldest_valid_budget_date(family) &&
        budget_start <= latest_valid_budget_start_date(family)
    end

    def find_or_bootstrap(family, start_date:, user: nil)
      return nil unless budget_date_valid?(start_date, family: family)

      Budget.transaction do
        if family.uses_custom_month_start?
          budget_start = family.custom_month_start_for(start_date)
          budget_end = family.custom_month_end_for(start_date)
        else
          budget_start = start_date.beginning_of_month
          budget_end = start_date.end_of_month
        end

        budget = Budget.find_or_create_by!(
          family: family,
          start_date: budget_start,
          end_date: budget_end
        ) do |b|
          b.currency = family.currency
        end

        budget.current_user = user
        budget.sync_budget_categories

        budget
      end
    end

    private
      def oldest_valid_budget_date(family)
        two_years_ago = 2.years.ago.beginning_of_month
        oldest_entry_date = family.oldest_entry_date.beginning_of_month
        [ two_years_ago, oldest_entry_date ].min
      end

      def latest_valid_budget_start_date(family)
        if family.uses_custom_month_start?
          family.current_custom_month_period.start_date + 2.years
        else
          Date.current.beginning_of_month + 2.years
        end
      end
  end

  def period
    Period.custom(start_date: start_date, end_date: end_date)
  end

  def to_param
    self.class.date_to_param(start_date)
  end

  def sync_budget_categories
    current_category_ids = family.categories.pluck(:id).to_set
    existing_budget_category_ids = budget_categories.pluck(:category_id).to_set
    categories_to_add = current_category_ids - existing_budget_category_ids
    categories_to_remove = existing_budget_category_ids - current_category_ids

    # Create missing categories
    categories_to_add.each do |category_id|
      budget_categories.create!(
        category_id: category_id,
        budgeted_spending: 0,
        currency: family.currency
      )
    end

    # Remove old categories
    budget_categories.where(category_id: categories_to_remove).destroy_all if categories_to_remove.any?

    recompute_values!
  end

  def uncategorized_budget_category
    budget_categories.uncategorized.tap do |bc|
      bc.budgeted_spending = [ available_to_allocate, 0 ].max
      bc.currency = family.currency
    end
  end

  def transactions
    scope = family.transactions.visible.in_period(period)
    if current_user
      scope = scope.joins(:entry).where(entries: { account_id: family.accounts.accessible_by(current_user).select(:id) })
    end
    scope
  end

  def name
    if family.uses_custom_month_start?
      I18n.t(
        "budgets.name.custom_range",
        start: start_date.strftime("%b %d"),
        end_date: end_date.strftime("%b %d, %Y")
      )
    else
      I18n.t("budgets.name.month_year", month: start_date.strftime("%B %Y"))
    end
  end

  def initialized?
    budgeted_spending.present?
  end

  def most_recent_initialized_budget
    family.budgets
      .includes(:budget_categories)
      .where("start_date < ?", start_date)
      .where.not(budgeted_spending: nil)
      .order(start_date: :desc)
      .first
  end

  def copy_from!(source_budget)
    raise ArgumentError, "source budget must belong to the same family" unless source_budget.family_id == family_id
    raise ArgumentError, "source budget must precede target budget" unless source_budget.start_date < start_date

    Budget.transaction do
      update!(
        budgeted_spending: source_budget.budgeted_spending,
        expected_income: source_budget.expected_income
      )

      target_by_category = budget_categories.index_by(&:category_id)

      source_budget.budget_categories.reload.each do |source_bc|
        target_bc = target_by_category[source_bc.category_id]
        next unless target_bc

        target_bc.update!(budgeted_spending: source_bc.budgeted_spending)
      end

      recompute_values!
    end
  end

  def income_category_totals
    net_totals.net_income_categories.reject { |ct| ct.total.zero? }.sort_by(&:weight).reverse
  end

  def expense_category_totals
    net_totals.net_expense_categories.reject { |ct| ct.total.zero? }.sort_by(&:weight).reverse
  end

  def current?
    if family.uses_custom_month_start?
      current_period = family.current_custom_month_period
      start_date == current_period.start_date && end_date == current_period.end_date
    else
      start_date == Date.current.beginning_of_month && end_date == Date.current.end_of_month
    end
  end

  def previous_budget_param
    previous_date = start_date - 1.month
    return nil unless self.class.budget_date_valid?(previous_date, family: family)

    self.class.date_to_param(previous_date)
  end

  def next_budget_param
    next_date = start_date + 1.month
    return nil unless self.class.budget_date_valid?(next_date, family: family)

    self.class.date_to_param(next_date)
  end

  def to_donut_segments_json
    unused_segment_id = "unused"

    # Continuous gray segment for empty budgets
    return [ { color: "var(--budget-unallocated-fill)", amount: 1, id: unused_segment_id } ] unless allocations_valid?

    segments = budget_categories.reject(&:subcategory?).map do |bc|
      { color: bc.category.color, amount: budget_category_actual_spending(bc), id: bc.id }
    end

    if available_to_spend.positive?
      segments.push({ color: "var(--budget-unallocated-fill)", amount: available_to_spend, id: unused_segment_id })
    end

    segments
  end

  # =============================================================================
  # Actuals: How much user has spent on each budget category
  # =============================================================================
  def estimated_spending
    return precomputed_estimated_spending if precomputed_estimated_spending.present?
    @estimated_spending ||= live_estimated_spending
  end

  def live_estimated_spending
    income_statement.median_expense(interval: "month")
  end

  def recompute_values!
    recompute_estimated_spending!
    recompute_category_values!
  end

  def recompute_estimated_spending!
    live_est = live_estimated_spending
    self.precomputed_estimated_spending = live_est
    update_columns(
      precomputed_estimated_spending: live_est,
      updated_at: Time.current
    )
  end

  def recompute_category_values!
    categories_list = budget_categories.reload.includes(:category).to_a
    return if categories_list.empty?

    actual_spendings = categories_list.each_with_object({}) do |bc, hash|
      hash[bc.id] = bc.live_actual_spending
    end

    top_level, sub_cats = categories_list.partition { |bc| !bc.subcategory? }

    available_spendings = {}

    top_level.each do |bc|
      actual = actual_spendings[bc.id] || 0
      parent_budget = bc[:budgeted_spending] || 0
      sub_with_limits = sub_cats.select { |s| (s.category.parent_id == bc.category_id || s.category.id == bc.category_id) && !s.inherits_parent_budget? }
      sub_budgets = sub_with_limits.sum { |sc| sc[:budgeted_spending] || 0 }
      shared_pool = parent_budget - sub_budgets
      sub_spending = sub_with_limits.sum { |sc| actual_spendings[sc.id] || 0 }
      shared_pool_spending = actual - sub_spending
      available_spendings[bc.id] = shared_pool - shared_pool_spending
    end

    sub_cats.each do |bc|
      if bc.inherits_parent_budget?
        parent = bc.parent_budget_category
        available_spendings[bc.id] = parent ? (available_spendings[parent.id] || 0) : 0
      else
        available_spendings[bc.id] = (bc[:budgeted_spending] || 0) - (actual_spendings[bc.id] || 0)
      end
    end

    categories_list.each do |bc|
      act = actual_spendings[bc.id] || 0
      avail = available_spendings[bc.id] || 0
      bc.precomputed_actual_spending = act
      bc.precomputed_available_to_spend = avail
      bc.update_columns(
        precomputed_actual_spending: act,
        precomputed_available_to_spend: avail,
        updated_at: Time.current
      )
    end
  end

  def actual_spending
    net_totals.total_net_expense
  end

  def budget_category_actual_spending(budget_category)
    key = budget_category.category_id || stable_synthetic_key(budget_category.category)
    expense = expense_totals_by_category[key]&.total || 0
    refund = income_totals_by_category[key]&.total || 0
    [ expense - refund, 0 ].max
  end

  def category_median_monthly_expense(category)
    @category_median_monthly_expense ||= {}
    key = category&.id || :uncategorized
    @category_median_monthly_expense[key] ||= income_statement.median_expense(category: category)
  end

  def category_avg_monthly_expense(category)
    @category_avg_monthly_expense ||= {}
    key = category&.id || :uncategorized
    @category_avg_monthly_expense[key] ||= income_statement.avg_expense(category: category)
  end

  def available_to_spend
    (budgeted_spending || 0) - actual_spending
  end

  def percent_of_budget_spent
    return 0 unless budgeted_spending > 0

    (actual_spending / budgeted_spending.to_f) * 100
  end

  def overage_percent
    return 0 unless available_to_spend.negative?

    available_to_spend.abs / actual_spending.to_f * 100
  end

  # =============================================================================
  # Budget allocations: How much user has budgeted for all parent categories combined
  # =============================================================================
  def allocated_spending
    budget_categories.reject { |bc| bc.subcategory? }.sum(&:budgeted_spending)
  end

  def allocated_percent
    return 0 unless budgeted_spending && budgeted_spending > 0

    (allocated_spending / budgeted_spending.to_f) * 100
  end

  def available_to_allocate
    (budgeted_spending || 0) - allocated_spending
  end

  def allocations_valid?
    initialized? && available_to_allocate >= 0 && allocated_spending > 0
  end

  # =============================================================================
  # Income: How much user earned relative to what they expected to earn
  # =============================================================================
  def estimated_income
    @estimated_income ||= income_statement.median_income(interval: "month")
  end

  def actual_income
    @actual_income ||= income_statement.income_totals(period: period).total
  end

  def actual_income_percent
    return 0 unless expected_income > 0

    (actual_income / expected_income.to_f) * 100
  end

  def remaining_expected_income
    expected_income - actual_income
  end

  def surplus_percent
    return 0 unless remaining_expected_income.negative?

    remaining_expected_income.abs / expected_income.to_f * 100
  end

  private
    def income_statement
      @income_statement ||= family.income_statement(user: current_user)
    end

    def net_totals
      @net_totals ||= income_statement.net_category_totals(period: period)
    end

    def expense_totals
      @expense_totals ||= income_statement.expense_totals(period: period)
    end

    def income_totals
      @income_totals ||= income_statement.income_totals(period: period)
    end

    def expense_totals_by_category
      @expense_totals_by_category ||= expense_totals.category_totals.index_by { |ct| ct.category.id || stable_synthetic_key(ct.category) }
    end

    def income_totals_by_category
      @income_totals_by_category ||= income_totals.category_totals.index_by { |ct| ct.category.id || stable_synthetic_key(ct.category) }
    end

    def stable_synthetic_key(category)
      if category.uncategorized?
        :uncategorized
      elsif category.other_investments?
        :other_investments
      end
    end
end
