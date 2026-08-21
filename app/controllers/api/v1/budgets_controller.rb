# frozen_string_literal: true

class Api::V1::BudgetsController < Api::V1::BaseController
  include Pagy::Backend

  before_action :ensure_read_scope, only: %i[index show]
  before_action :ensure_write_scope, only: %i[create update destroy]
  before_action :set_budget, only: %i[show update destroy]

  def index
    @per_page = safe_per_page_param

    @pagy, @budgets = pagy(
      current_resource_owner.family.budgets.order(start_date: :desc, id: :asc),
      page: safe_page_param,
      limit: @per_page
    )

    render :index
  rescue => e
    Rails.logger.error "BudgetsController#index error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  def show
    render :show
  rescue => e
    Rails.logger.error "BudgetsController#show error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  def create
    family = current_resource_owner.family
    @budget = family.budgets.new(budget_params)
    @budget.currency ||= family.currency
    if @budget.start_date.present? && @budget.end_date.blank?
      @budget.end_date = @budget.start_date.end_of_month
    end

    if @budget.save
      @budget.sync_budget_categories
      render :show, status: :created
    else
      render json: {
        error: "validation_failed",
        message: "Budget could not be created",
        errors: @budget.errors.full_messages
      }, status: :unprocessable_entity
    end
  rescue => e
    Rails.logger.error "BudgetsController#create error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  def update
    if @budget.update(budget_params)
      render :show
    else
      render json: {
        error: "validation_failed",
        message: "Budget could not be updated",
        errors: @budget.errors.full_messages
      }, status: :unprocessable_entity
    end
  rescue => e
    Rails.logger.error "BudgetsController#update error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  def destroy
    @budget.destroy!
    head :no_content
  rescue => e
    Rails.logger.error "BudgetsController#destroy error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  private

    def set_budget
      @budget = current_resource_owner.family.budgets.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: {
        error: "not_found",
        message: "Budget not found"
      }, status: :not_found
    end

    def ensure_read_scope
      authorize_scope!(:read)
    end

    def ensure_write_scope
      authorize_scope!(:write)
    end

    def budget_params
      params.require(:budget).permit(:start_date, :end_date, :currency, :budgeted_spending, :expected_income)
    end

    def safe_page_param
      page = params[:page].to_i
      page > 0 ? page : 1
    end

    def safe_per_page_param
      per_page = params[:per_page].to_i

      case per_page
      when 1..100
        per_page
      else
        25
      end
    end
end
