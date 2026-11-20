class PurchaseOrderInvoicePhotosController < ApplicationController
  include RequireBusinessMode
  include ActiveStorage::Streaming

  before_action :set_purchase_order
  before_action :ensure_writable_purchase_order!, only: %i[create destroy]

  def show
    if @purchase_order.invoice_photo.attached?
      disposition = params[:disposition] == "attachment" ? "attachment" : "inline"
      send_blob_stream @purchase_order.invoice_photo.blob, disposition: disposition
    else
      head :not_found
    end
  end

  def create
    file = params[:invoice_photo] || params[:file] || params.dig(:purchase_order, :invoice_photo)

    if file.blank?
      redirect_to @purchase_order, alert: t("purchase_orders.invoice_photo.file_required")
      return
    end

    @purchase_order.invoice_photo.attach(file)

    if @purchase_order.valid?
      redirect_to @purchase_order, notice: t("purchase_orders.invoice_photo.uploaded")
    else
      @purchase_order.invoice_photo.purge
      redirect_to @purchase_order, alert: @purchase_order.errors.full_messages.to_sentence
    end
  end

  def destroy
    @purchase_order.invoice_photo.purge if @purchase_order.invoice_photo.attached?
    redirect_to @purchase_order, notice: t("purchase_orders.invoice_photo.deleted")
  end

  private

    def set_purchase_order
      @purchase_order = Current.family.purchase_orders.find(params[:purchase_order_id])
    end

    def ensure_writable_purchase_order!
      return if Current.family.accounts.writable_by(Current.user).exists?(id: @purchase_order.account_id)

      head :forbidden
    end
end
