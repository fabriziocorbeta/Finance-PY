class BudgetsController < ApplicationController
  before_action :set_budget, only: %i[show edit update copy_previous]

  def index
    redirect_to_current_month_budget
  end

  def show
    @source_budget = @budget.most_recent_initialized_budget unless @budget.initialized?
  end

  def edit
    render layout: "wizard"
  end

  def update
    @budget.update!(budget_params)
    redirect_to budget_budget_categories_path(@budget)
  end

  def copy_previous
    if @budget.initialized?
      redirect_to budget_path(@budget), alert: t("budgets.copy_previous.already_initialized")
      return
    end

    source_budget = @budget.most_recent_initialized_budget

    if source_budget
      @budget.copy_from!(source_budget)
      redirect_to budget_budget_categories_path(@budget), notice: t("budgets.copy_previous.success", source_name: source_budget.name)
    else
      redirect_to budget_path(@budget), alert: t("budgets.copy_previous.no_source")
    end
  end

  def picker
    render partial: "budgets/picker", locals: {
      family: Current.family,
      year: params[:year].to_i || Date.current.year
    }
  end

  private

    def budget_create_params
      params.require(:budget).permit(:start_date)
    end

    def budget_params
      params.require(:budget).permit(:budgeted_spending, :expected_income)
    end

    def set_budget
      start_date = Budget.param_to_date(params[:month_year], family: Current.family)
      Current.family.preload_cache_versions_async(date_range: start_date.beginning_of_month..start_date.end_of_month)
      @budget = Budget.find_or_bootstrap(Current.family, start_date: start_date, user: Current.user)
      raise ActiveRecord::RecordNotFound unless @budget

      @budget.budget_categories.load_async
    end

    def redirect_to_current_month_budget
      current_budget = Budget.find_or_bootstrap(Current.family, start_date: Date.current, user: Current.user)
      redirect_to budget_path(current_budget)
    end
end
