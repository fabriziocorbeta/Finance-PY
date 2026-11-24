# frozen_string_literal: true

class Api::V1::SalesController < Api::V1::BaseController
  include Pagy::Backend
  include ActiveStorage::Streaming

  before_action :ensure_read_scope, only: %i[index show invoice_photo]
  before_action :ensure_write_scope, only: %i[create update destroy complete cancel upload_invoice_photo delete_invoice_photo]
  before_action :require_business_mode!
  before_action :set_sale, only: %i[show update destroy complete cancel invoice_photo upload_invoice_photo delete_invoice_photo]
  before_action :ensure_writable_sale_account!, only: %i[update destroy complete cancel upload_invoice_photo delete_invoice_photo]

  def index
    @per_page = safe_per_page_param

    @pagy, @sales = pagy(
      sales_scope.includes(sale_items: :product, invoice_photo_attachment: :blob).order(created_at: :desc, id: :asc),
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
    @sale = current_family.sales.new(sale_params)

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
    updated = false
    validation_errors = nil

    @sale.with_lock do
      unless @sale.draft?
        validation_errors = [ "Only draft sales can be updated" ]
        next
      end

      if @sale.update(sale_params)
        updated = true
      else
        validation_errors = @sale.errors.full_messages
      end
    end

    if updated
      render :show, status: :ok
    else
      render_validation_error(validation_errors || @sale.errors.full_messages)
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
    destroyed = false
    validation_errors = nil

    @sale.with_lock do
      unless @sale.draft?
        validation_errors = [ "Cannot delete a sale that is not in draft status. Cancel it first." ]
        next
      end

      if @sale.destroy
        destroyed = true
      else
        validation_errors = @sale.errors.full_messages
      end
    end

    if destroyed
      head :no_content
    else
      render_validation_error(validation_errors || @sale.errors.full_messages)
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

  def invoice_photo
    if @sale.invoice_photo.attached?
      disposition = params[:disposition] == "attachment" ? "attachment" : "inline"
      send_blob_stream @sale.invoice_photo.blob, disposition: disposition
    else
      render json: {
        error: "not_found",
        message: "Invoice photo not found"
      }, status: :not_found
    end
  end

  def upload_invoice_photo
    file = params[:invoice_photo] || params[:file] || params.dig(:sale, :invoice_photo)

    if file.blank?
      return render_validation_error([ "Invoice photo file is required" ])
    end

    @sale.invoice_photo.attach(file)

    if @sale.valid?
      render :show, status: :ok
    else
      @sale.invoice_photo.purge
      render_validation_error(@sale.errors.full_messages)
    end
  rescue => e
    Rails.logger.error "SalesController#upload_invoice_photo error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  def delete_invoice_photo
    @sale.invoice_photo.purge if @sale.invoice_photo.attached?
    render :show, status: :ok
  rescue => e
    Rails.logger.error "SalesController#delete_invoice_photo error: #{e.message}"
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

    def ensure_writable_sale_account!
      return if current_family.accounts.writable_by(current_resource_owner).exists?(id: @sale.account_id)

      render json: {
        error: "forbidden",
        message: "You do not have write access to this account"
      }, status: :forbidden
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
      accessible_ids = current_family.accounts.accessible_by(current_resource_owner).select(:id)
      current_family.sales.where(account_id: accessible_ids)
    end

    def sale_params
      raw = params.key?(:sale) ? params.require(:sale) : params
      permitted = raw.permit(
        :client_name, :currency, :payment_method, :invoice_number, :condition, :notes,
        :delivery_address, :delivery_date, :carrier, :invoice_photo,
        sale_items_attributes: [ :id, :product_id, :quantity, :unit_price, :_destroy ]
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
