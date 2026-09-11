# frozen_string_literal: true

class Api::V1::GoalPledgesController < Api::V1::BaseController
  include Pagy::Backend

  before_action :ensure_read_scope, only: %i[index]
  before_action :ensure_write_scope, only: %i[create destroy renew]
  before_action :set_goal
  before_action :set_pledge, only: %i[destroy renew]

  def index
    @per_page = safe_per_page_param

    @pagy, @goal_pledges = pagy(
      @goal.goal_pledges.includes(:account).order(created_at: :desc, id: :asc),
      page: safe_page_param,
      limit: @per_page
    )

    render :index
  rescue => e
    Rails.logger.error "GoalPledgesController#index error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  def create
    raw_params = pledge_raw_params
    account_id = raw_params[:account_id]
    account = @goal.linked_accounts.find_by(id: account_id) || current_resource_owner.family.accounts.find_by(id: account_id)

    @pledge = @goal.goal_pledges.build(
      amount: raw_params[:amount],
      account: account,
      kind: account&.default_pledge_kind || "transfer",
      currency: @goal.currency
    )

    if @pledge.save
      render :show, status: :created
    else
      render json: {
        error: "validation_failed",
        message: "Goal pledge could not be created",
        errors: @pledge.errors.full_messages
      }, status: :unprocessable_entity
    end
  rescue ActionController::ParameterMissing => e
    render json: {
      error: "bad_request",
      message: e.message
    }, status: :bad_request
  rescue => e
    Rails.logger.error "GoalPledgesController#create error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  def destroy
    @pledge.cancel!
    render :show, status: :ok
  rescue GoalPledge::NotOpenError => e
    render json: {
      error: "validation_failed",
      message: e.message,
      errors: [ e.message ]
    }, status: :unprocessable_entity
  rescue => e
    Rails.logger.error "GoalPledgesController#destroy error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  def renew
    @pledge.extend!(days: 7)
    render :show, status: :ok
  rescue GoalPledge::NotOpenError => e
    render json: {
      error: "validation_failed",
      message: e.message,
      errors: [ e.message ]
    }, status: :unprocessable_entity
  rescue => e
    Rails.logger.error "GoalPledgesController#renew error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  private

    def set_goal
      @goal = current_resource_owner.family.goals.find(params[:goal_id])
    rescue ActiveRecord::RecordNotFound
      render json: {
        error: "not_found",
        message: "Goal not found"
      }, status: :not_found
    end

    def set_pledge
      return if performed?
      @pledge = @goal.goal_pledges.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: {
        error: "not_found",
        message: "Goal pledge not found"
      }, status: :not_found
    end

    def ensure_read_scope
      authorize_scope!(:read)
    end

    def ensure_write_scope
      authorize_scope!(:write)
    end

    def pledge_raw_params
      params.key?(:pledge) ? params.require(:pledge) : params
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
