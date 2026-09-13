# frozen_string_literal: true

class Api::V1::FuelLogsController < Api::V1::BaseController
  before_action :ensure_write_scope
  before_action :set_fleet_vehicle
  before_action :set_fuel_log, only: %i[update destroy]

  def create
    @fuel_log = @fleet_vehicle.fuel_logs.build(fuel_log_attributes)

    if @fuel_log.save
      render :show, status: :created
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
    if @fuel_log.update(fuel_log_attributes)
      render :show, status: :ok
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
    render json: {
      message: "Fuel log deleted successfully"
    }, status: :ok
  rescue => e
    Rails.logger.error "FuelLogsController#destroy error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  private

    def ensure_write_scope
      authorize_scope!(:write)
    end

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

    def raw_fuel_log_params
      raw = params.key?(:fuel_log) ? params.require(:fuel_log) : params

      if raw[:fuel_log_lines].present? && !raw.key?(:fuel_log_lines_attributes)
        raw[:fuel_log_lines_attributes] = raw[:fuel_log_lines]
      end

      raw
    end

    def extracted_fuel_log_params
      raw_fuel_log_params.permit(
        :logged_at, :odometer, :liters, :cost, :notes,
        fuel_log_lines_attributes: [ :id, :fuel_type, :brand, :liters, :cost, :_destroy ]
      )
    end

    # account_id NO se permite vía .permit (Brakeman PermitAttributes, alta
    # confianza) — se resuelve acá explícito, acotado a las cuentas de la
    # family del usuario. El modelo también valida account.family_id ==
    # fleet_vehicle.family_id, pero resolverlo así acá deja el alcance
    # permitido explícito en el controller en vez de depender solo de eso.
    def fuel_log_attributes
      attrs = extracted_fuel_log_params.to_h.symbolize_keys
      account_id = raw_fuel_log_params[:account_id]
      return attrs if account_id.blank?

      attrs[:account] = current_resource_owner.family.accounts.find_by(id: account_id)
      attrs
    end
end
