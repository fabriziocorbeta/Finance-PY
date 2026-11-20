# frozen_string_literal: true

class Api::V1::PurchaseOrdersController < Api::V1::BaseController
  include Pagy::Backend
  include ActiveStorage::Streaming

  before_action :ensure_read_scope, only: %i[index show invoice_photo]
  before_action :ensure_write_scope, only: %i[create update destroy receive cancel upload_invoice_photo delete_invoice_photo]
  before_action :require_business_mode!
  before_action :set_purchase_order, only: %i[show update destroy receive cancel invoice_photo upload_invoice_photo delete_invoice_photo]
  before_action :ensure_writable_purchase_order_account!, only: %i[upload_invoice_photo delete_invoice_photo]

  def index
    @per_page = safe_per_page_param

    @pagy, @purchase_orders = pagy(
      purchase_orders_scope.includes(purchase_order_items: :product, invoice_photo_attachment: :blob).order(created_at: :desc, id: :asc),
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
    @purchase_order = current_family.purchase_orders.new(purchase_order_params)

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

  def invoice_photo
    if @purchase_order.invoice_photo.attached?
      disposition = params[:disposition] == "attachment" ? "attachment" : "inline"
      send_blob_stream @purchase_order.invoice_photo.blob, disposition: disposition
    else
      render json: {
        error: "not_found",
        message: "Invoice photo not found"
      }, status: :not_found
    end
  end

  def upload_invoice_photo
    file = params[:invoice_photo] || params[:file] || params.dig(:purchase_order, :invoice_photo)

    if file.blank?
      return render_validation_error([ "Invoice photo file is required" ])
    end

    @purchase_order.invoice_photo.attach(file)

    if @purchase_order.valid?
      render :show, status: :ok
    else
      @purchase_order.invoice_photo.purge
      render_validation_error(@purchase_order.errors.full_messages)
    end
  rescue => e
    Rails.logger.error "PurchaseOrdersController#upload_invoice_photo error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  def delete_invoice_photo
    @purchase_order.invoice_photo.purge if @purchase_order.invoice_photo.attached?
    render :show, status: :ok
  rescue => e
    Rails.logger.error "PurchaseOrdersController#delete_invoice_photo error: #{e.message}"
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

    def ensure_writable_purchase_order_account!
      return if current_family.accounts.writable_by(current_resource_owner).exists?(id: @purchase_order.account_id)

      render json: {
        error: "forbidden",
        message: "You do not have write access to this account"
      }, status: :forbidden
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
      current_family.purchase_orders
    end

    def purchase_order_params
      raw = params.key?(:purchase_order) ? params.require(:purchase_order) : params
      permitted = raw.permit(
        :supplier_name, :currency, :expected_date, :notes, :invoice_photo,
        purchase_order_items_attributes: [ :id, :product_id, :quantity, :unit_cost, :_destroy ]
      )

      # account_id is deliberately NOT mass-assigned: resolve it inside the
      # accounts the caller can write to, so neither a foreign account id nor
      # a family account the caller only has read access to can be attached.
      if raw.respond_to?(:key?) && raw.key?(:account_id)
        permitted[:account_id] = current_family.accounts.writable_by(current_resource_owner).find_by(id: raw[:account_id])&.id
      end
      permitted
    end
end
