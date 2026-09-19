# frozen_string_literal: true

class Api::V1::PurchaseOrdersController < Api::V1::BaseController
  include Pagy::Backend

  before_action :ensure_read_scope, only: %i[index show]
  before_action :ensure_write_scope, only: %i[create update destroy receive cancel]
  before_action :require_business_mode!
  before_action :set_purchase_order, only: %i[show update destroy receive cancel]

  def index
    @per_page = safe_per_page_param

    @pagy, @purchase_orders = pagy(
      purchase_orders_scope.includes(purchase_order_items: :product).order(created_at: :desc, id: :asc),
      page: safe_page_param,
      limit: @per_page
    )

    render :index
  rescue => e
    Rails.logger.error "PurchaseOrdersController#index error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  def show
    render :show
  rescue => e
    Rails.logger.error "PurchaseOrdersController#show error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  def create
    @purchase_order = current_resource_owner.family.purchase_orders.new(purchase_order_params)

    if @purchase_order.save
      render :show, status: :created
    else
      render_validation_error(@purchase_order.errors.full_messages)
    end
  rescue ActiveRecord::RecordInvalid => e
    render_validation_error(e.record.errors.full_messages)
  rescue => e
    Rails.logger.error "PurchaseOrdersController#create error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  def update
    unless @purchase_order.draft?
      return render_validation_error([ "Only draft purchase orders can be updated" ])
    end

    if @purchase_order.update(purchase_order_params)
      render :show, status: :ok
    else
      render_validation_error(@purchase_order.errors.full_messages)
    end
  rescue ActiveRecord::RecordInvalid => e
    render_validation_error(e.record.errors.full_messages)
  rescue => e
    Rails.logger.error "PurchaseOrdersController#update error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  def destroy
    unless @purchase_order.draft?
      return render_validation_error([ "Cannot delete a purchase order that is not in draft status. Cancel it first." ])
    end

    if @purchase_order.destroy
      head :no_content
    else
      render_validation_error(@purchase_order.errors.full_messages)
    end
  rescue => e
    Rails.logger.error "PurchaseOrdersController#destroy error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  def receive
    @purchase_order.receive!
    render :show, status: :ok
  rescue ActiveRecord::RecordInvalid => e
    render_validation_error(e.record.errors.full_messages)
  rescue => e
    Rails.logger.error "PurchaseOrdersController#receive error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  def cancel
    @purchase_order.cancel!
    render :show, status: :ok
  rescue ActiveRecord::RecordInvalid => e
    render_validation_error(e.record.errors.full_messages)
  rescue => e
    Rails.logger.error "PurchaseOrdersController#cancel error: #{e.message}"
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

    def set_purchase_order
      @purchase_order = purchase_orders_scope.includes(purchase_order_items: :product).find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: {
        error: "not_found",
        message: "Purchase order not found"
      }, status: :not_found
    end

    def purchase_orders_scope
      current_resource_owner.family.purchase_orders
    end

    def purchase_order_params
      raw = params.key?(:purchase_order) ? params.require(:purchase_order) : params
      permitted = raw.permit(
        :supplier_name, :currency, :expected_date, :notes,
        purchase_order_items_attributes: [ :id, :product_id, :quantity, :unit_cost, :_destroy ]
      )

      # account_id is deliberately NOT mass-assigned: resolve it inside the caller's
      # own family so a foreign account id can never be attached.
      if raw.respond_to?(:key?) && raw.key?(:account_id)
        permitted[:account_id] = current_resource_owner.family.accounts.find_by(id: raw[:account_id])&.id
      end
      permitted
    end
end
