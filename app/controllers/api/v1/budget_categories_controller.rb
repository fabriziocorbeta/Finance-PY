# frozen_string_literal: true

class Api::V1::BudgetCategoriesController < Api::V1::BaseController
  before_action :ensure_read_scope, only: %i[index show]
  before_action :ensure_write_scope, only: %i[update]
  before_action :set_budget
  before_action :set_budget_category, only: %i[show update]

  def index
    @budget_categories = @budget.budget_categories.includes(:category)
    render :index
  rescue => e
    Rails.logger.error "BudgetCategoriesController#index error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  def show
    render :show
  rescue => e
    Rails.logger.error "BudgetCategoriesController#show error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  def update
    @budget_category.update_budgeted_spending!(budgeted_spending_param)
    render :show
  rescue ActiveRecord::RecordInvalid => e
    render json: {
      error: "validation_failed",
      message: "Budget category could not be updated",
      errors: e.record.errors.full_messages
    }, status: :unprocessable_entity
  rescue => e
    Rails.logger.error "BudgetCategoriesController#update error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  private

    def set_budget
      @budget = current_resource_owner.family.budgets.find(params[:budget_id])
    rescue ActiveRecord::RecordNotFound
      render json: {
        error: "not_found",
        message: "Budget not found"
      }, status: :not_found
    end

    def set_budget_category
      @budget_category = @budget.budget_categories.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: {
        error: "not_found",
        message: "Budget category not found"
      }, status: :not_found
    end

    def ensure_read_scope
      authorize_scope!(:read)
    end

    def ensure_write_scope
      authorize_scope!(:write)
    end

    def budgeted_spending_param
      params.require(:budget_category).permit(:budgeted_spending).fetch(:budgeted_spending, nil).presence || 0
    end
end
