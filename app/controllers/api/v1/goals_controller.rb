# frozen_string_literal: true

class Api::V1::GoalsController < Api::V1::BaseController
  include Pagy::Backend

  before_action :ensure_read_scope

  def index
    @per_page = safe_per_page_param

    @pagy, @goals = pagy(
      current_resource_owner.family.goals.order(created_at: :desc, id: :asc),
      page: safe_page_param,
      limit: @per_page
    )

    render :index
  rescue => e
    Rails.logger.error "GoalsController#index error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  def show
    @goal = current_resource_owner.family.goals.find(params[:id])

    render :show
  rescue ActiveRecord::RecordNotFound
    render json: {
      error: "not_found",
      message: "Goal not found"
    }, status: :not_found
  rescue => e
    Rails.logger.error "GoalsController#show error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  private

    def ensure_read_scope
      authorize_scope!(:read)
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
