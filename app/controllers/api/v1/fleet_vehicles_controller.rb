# frozen_string_literal: true

class Api::V1::FleetVehiclesController < Api::V1::BaseController
  include Pagy::Backend

  before_action :ensure_read_scope, only: %i[index show]
  before_action :ensure_write_scope, only: %i[create update destroy]
  before_action :set_fleet_vehicle, only: %i[show update destroy]

  def index
    @per_page = safe_per_page_param

    @pagy, @fleet_vehicles = pagy(
      current_resource_owner.family.fleet_vehicles.order(created_at: :desc, id: :asc),
      page: safe_page_param,
      limit: @per_page
    )

    render :index
  rescue => e
    Rails.logger.error "FleetVehiclesController#index error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  def show
    render :show
  rescue => e
    Rails.logger.error "FleetVehiclesController#show error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  def create
    @fleet_vehicle = current_resource_owner.family.fleet_vehicles.new(fleet_vehicle_params)

    if @fleet_vehicle.save
      render :show, status: :created
    else
      render json: {
        error: "validation_failed",
        message: "Fleet vehicle could not be created",
        errors: @fleet_vehicle.errors.full_messages
      }, status: :unprocessable_entity
    end
  rescue ActionController::ParameterMissing => e
    render json: {
      error: "bad_request",
      message: e.message
    }, status: :bad_request
  rescue => e
    Rails.logger.error "FleetVehiclesController#create error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  def update
    if @fleet_vehicle.update(fleet_vehicle_params)
      render :show, status: :ok
    else
      render json: {
        error: "validation_failed",
        message: "Fleet vehicle could not be updated",
        errors: @fleet_vehicle.errors.full_messages
      }, status: :unprocessable_entity
    end
  rescue ActionController::ParameterMissing => e
    render json: {
      error: "bad_request",
      message: e.message
    }, status: :bad_request
  rescue => e
    Rails.logger.error "FleetVehiclesController#update error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  def destroy
    @fleet_vehicle.destroy!
    head :no_content
  rescue => e
    Rails.logger.error "FleetVehiclesController#destroy error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  private

    def set_fleet_vehicle
      @fleet_vehicle = current_resource_owner.family.fleet_vehicles.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: {
        error: "not_found",
        message: "Fleet vehicle not found"
      }, status: :not_found
    end

    def ensure_read_scope
      authorize_scope!(:read)
    end

    def ensure_write_scope
      authorize_scope!(:write)
    end

    def fleet_vehicle_params
      raw_params = params.key?(:fleet_vehicle) ? params.require(:fleet_vehicle) : params
      raw_params.permit(:plate, :brand, :model, :year, :status, :notes)
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
