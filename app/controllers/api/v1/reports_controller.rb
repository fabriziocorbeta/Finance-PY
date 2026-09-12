# frozen_string_literal: true

class Api::V1::ReportsController < Api::V1::BaseController
  before_action :ensure_read_scope

  # GET /api/v1/reports/summary
  def summary
    builder = Reports::SummaryBuilder.new(
      family: current_resource_owner.family,
      user: current_resource_owner,
      period_type: params[:period_type],
      start_date: params[:start_date],
      end_date: params[:end_date]
    )

    render json: builder.build_all
  rescue => e
    Rails.logger.error "ReportsController#summary error: #{e.message}"
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
end
