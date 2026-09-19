# frozen_string_literal: true

class Api::V1::SalesController < Api::V1::BaseController
  include Pagy::Backend

  before_action :ensure_read_scope, only: %i[index show]
  before_action :ensure_write_scope, only: %i[create update destroy complete cancel]
  before_action :require_business_mode!
  before_action :set_sale, only: %i[show update destroy complete cancel]

  def index
    @per_page = safe_per_page_param

    @pagy, @sales = pagy(
      sales_scope.includes(sale_items: :product).order(created_at: :desc, id: :asc),
      page: safe_page_param,
      limit: @per_page
    )

    render :index
  rescue => e
    Rails.logger.error "SalesController#index error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  def show
    render :show
  rescue => e
    Rails.logger.error "SalesController#show error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  def create
    @sale = current_resource_owner.family.sales.new(sale_params)

    if @sale.save
      render :show, status: :created
    else
      render_validation_error(@sale.errors.full_messages)
    end
  rescue ActiveRecord::RecordInvalid => e
    render_validation_error(e.record.errors.full_messages)
  rescue => e
    Rails.logger.error "SalesController#create error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  def update
    unless @sale.draft?
      return render_validation_error([ "Only draft sales can be updated" ])
    end

    if @sale.update(sale_params)
      render :show, status: :ok
    else
      render_validation_error(@sale.errors.full_messages)
    end
  rescue ActiveRecord::RecordInvalid => e
    render_validation_error(e.record.errors.full_messages)
  rescue => e
    Rails.logger.error "SalesController#update error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  def destroy
    unless @sale.draft?
      return render_validation_error([ "Cannot delete a sale that is not in draft status. Cancel it first." ])
    end

    if @sale.destroy
      head :no_content
    else
      render_validation_error(@sale.errors.full_messages)
    end
  rescue => e
    Rails.logger.error "SalesController#destroy error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  def complete
    @sale.complete!
    render :show, status: :ok
  rescue ActiveRecord::RecordInvalid => e
    render_validation_error(e.record.errors.full_messages)
  rescue => e
    Rails.logger.error "SalesController#complete error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  def cancel
    @sale.cancel!
    render :show, status: :ok
  rescue ActiveRecord::RecordInvalid => e
    render_validation_error(e.record.errors.full_messages)
  rescue => e
    Rails.logger.error "SalesController#cancel error: #{e.message}"
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

    def ensure_write_scope
      authorize_scope!(:write)
    end

    def set_sale
      @sale = sales_scope.includes(sale_items: :product).find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: {
        error: "not_found",
        message: "Sale not found"
      }, status: :not_found
    end

    def sales_scope
      current_resource_owner.family.sales
    end

    def sale_params
      raw = params.key?(:sale) ? params.require(:sale) : params
      permitted = raw.permit(
        :client_name, :currency, :payment_method, :invoice_number, :condition, :notes,
        :delivery_address, :delivery_date, :carrier,
        sale_items_attributes: [ :id, :product_id, :quantity, :unit_price, :_destroy ]
      )

      # account_id is deliberately NOT mass-assigned: resolve it inside the caller's
      # own family so a foreign account id can never be attached.
      if raw.respond_to?(:key?) && raw.key?(:account_id)
        permitted[:account_id] = current_resource_owner.family.accounts.find_by(id: raw[:account_id])&.id
      end
      permitted
    end
end
