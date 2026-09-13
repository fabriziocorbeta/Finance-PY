# frozen_string_literal: true

class Api::V1::ProductsController < Api::V1::BaseController
  include Pagy::Backend

  before_action :ensure_read_scope, only: %i[index show]
  before_action :ensure_write_scope, only: %i[create update destroy]
  before_action :require_business_mode!
  before_action :set_product, only: %i[show update destroy]

  def index
    @per_page = safe_per_page_param

    @pagy, @products = pagy(
      products_scope.order(name: :asc, id: :asc),
      page: safe_page_param,
      limit: @per_page
    )

    render :index
  rescue => e
    Rails.logger.error "ProductsController#index error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  def show
    render :show
  rescue => e
    Rails.logger.error "ProductsController#show error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  def create
    raw = product_raw_params
    cleaned_params = product_params(raw).except(:initial_stock, :stock)
    initial_stock = (raw[:initial_stock] || raw[:stock] || 0).to_i

    if initial_stock < 0
      return render_validation_error(["Initial stock must be zero or positive"])
    end

    @product = current_resource_owner.family.products.new(cleaned_params)

    saved = Product.transaction do
      if @product.save
        if initial_stock > 0
          @product.stock_movements.create!(
            reason: "entrada",
            quantity_delta: initial_stock
          )
        end
        true
      else
        false
      end
    end

    # render fuera de la transacción: ProductStockMovement actualiza
    # Product#stock en un after_create_commit, que solo corre una vez el
    # commit real sucede — si renderizás adentro del bloque .transaction,
    # el commit todavía no pasó y @product.stock queda con el valor viejo.
    if saved
      render :show, status: :created
    else
      render_validation_error(@product.errors.full_messages)
    end
  rescue ActiveRecord::RecordInvalid => e
    render_validation_error(e.record.errors.full_messages)
  rescue => e
    Rails.logger.error "ProductsController#create error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  def update
    raw = product_raw_params
    cleaned_params = product_params(raw).except(:initial_stock, :stock)

    if @product.update(cleaned_params)
      render :show, status: :ok
    else
      render_validation_error(@product.errors.full_messages)
    end
  rescue => e
    Rails.logger.error "ProductsController#update error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  def destroy
    if @product.destroy
      head :no_content
    else
      render_validation_error(@product.errors.full_messages)
    end
  rescue => e
    Rails.logger.error "ProductsController#destroy error: #{e.message}"
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

    def set_product
      @product = products_scope.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: {
        error: "not_found",
        message: "Product not found"
      }, status: :not_found
    end

    def products_scope
      current_resource_owner.family.products
    end

    def product_raw_params
      params.key?(:product) ? params.require(:product) : params
    end

    def product_params(raw)
      raw.permit(
        :name, :sku, :category, :supplier, :buy_price, :sell_price,
        :currency, :min_stock, :description, :initial_stock, :stock
      )
    end
end
