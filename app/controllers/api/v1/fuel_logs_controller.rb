# frozen_string_literal: true

class Api::V1::FuelLogsController < Api::V1::BaseController
  before_action :ensure_write_scope
  before_action :set_fleet_vehicle
  before_action :set_fuel_log, only: %i[update destroy]

  def create
    @fuel_log = @fleet_vehicle.fuel_logs.build(fuel_log_params)

    if @fuel_log.save
      render_fuel_log(@fuel_log, status: :created)
    else
      render json: {
        error: "validation_failed",
        message: "Fuel log could not be created",
        errors: @fuel_log.errors.full_messages
      }, status: :unprocessable_entity
    end
  rescue ActionController::ParameterMissing => e
    render json: {
      error: "bad_request",
      message: e.message
    }, status: :bad_request
  rescue => e
    Rails.logger.error "FuelLogsController#create error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  def update
    if @fuel_log.update(fuel_log_params)
      render_fuel_log(@fuel_log, status: :ok)
    else
      render json: {
        error: "validation_failed",
        message: "Fuel log could not be updated",
        errors: @fuel_log.errors.full_messages
      }, status: :unprocessable_entity
    end
  rescue ActionController::ParameterMissing => e
    render json: {
      error: "bad_request",
      message: e.message
    }, status: :bad_request
  rescue => e
    Rails.logger.error "FuelLogsController#update error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  def destroy
    @fuel_log.destroy!
    head :no_content
  rescue => e
    Rails.logger.error "FuelLogsController#destroy error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  private

    def set_fleet_vehicle
      @fleet_vehicle = current_resource_owner.family.fleet_vehicles.find(params[:fleet_vehicle_id])
    rescue ActiveRecord::RecordNotFound
      render json: {
        error: "not_found",
        message: "Fleet vehicle not found"
      }, status: :not_found
    end

    def set_fuel_log
      @fuel_log = @fleet_vehicle.fuel_logs.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: {
        error: "not_found",
        message: "Fuel log not found"
      }, status: :not_found
    end

    def ensure_write_scope
      authorize_scope!(:write)
    end

    def fuel_log_params
      raw_params = params.key?(:fuel_log) ? params.require(:fuel_log) : params

      # Transform fuel_log_lines to fuel_log_lines_attributes if passed as direct list
      if raw_params[:fuel_log_lines].present? && raw_params[:fuel_log_lines_attributes].blank?
        raw_params[:fuel_log_lines_attributes] = raw_params[:fuel_log_lines]
      end

      raw_params.permit(
        :odometer, :account_id, :logged_at, :notes, :liters, :cost,
        fuel_log_lines_attributes: [ :id, :fuel_type, :brand, :liters, :cost, :_destroy ]
      )
    end

    def render_fuel_log(fuel_log, status: :ok)
      render json: {
        id: fuel_log.id,
        fleet_vehicle_id: fuel_log.fleet_vehicle_id,
        account_id: fuel_log.account_id,
        entry_id: fuel_log.entry_id,
        liters: fuel_log.liters.to_f,
        cost: fuel_log.cost.to_f,
        odometer: fuel_log.odometer,
        logged_at: fuel_log.logged_at.iso8601,
        notes: fuel_log.notes,
        created_at: fuel_log.created_at.iso8601,
        updated_at: fuel_log.updated_at.iso8601,
        fuel_log_lines: fuel_log.fuel_log_lines.map { |line|
          {
            id: line.id,
            fuel_type: line.fuel_type,
            brand: line.brand,
            liters: line.liters.to_f,
            cost: line.cost.to_f,
            created_at: line.created_at.iso8601,
            updated_at: line.updated_at.iso8601
          }
        }
      }, status: status
    end
end
