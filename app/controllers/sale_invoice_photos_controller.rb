class SaleInvoicePhotosController < ApplicationController
  include RequireBusinessMode
  include ActiveStorage::Streaming

  before_action :set_sale
  before_action :ensure_writable_sale!, only: %i[create destroy]

  def show
    if @sale.invoice_photo.attached?
      disposition = params[:disposition] == "attachment" ? "attachment" : "inline"
      send_blob_stream @sale.invoice_photo.blob, disposition: disposition
    else
      head :not_found
    end
  end

  def create
    file = params[:invoice_photo] || params[:file] || params.dig(:sale, :invoice_photo)

    if file.blank?
      redirect_to @sale, alert: t("sales.invoice_photo.file_required")
      return
    end

    @sale.invoice_photo.attach(file)

    if @sale.valid?
      redirect_to @sale, notice: t("sales.invoice_photo.uploaded")
    else
      @sale.invoice_photo.purge
      redirect_to @sale, alert: @sale.errors.full_messages.to_sentence
    end
  end

  def destroy
    @sale.invoice_photo.purge if @sale.invoice_photo.attached?
    redirect_to @sale, notice: t("sales.invoice_photo.deleted")
  end

  private

    def set_sale
      @sale = Current.family.sales.find(params[:sale_id])
    end

    def ensure_writable_sale!
      return if Current.family.accounts.writable_by(Current.user).exists?(id: @sale.account_id)

      head :forbidden
    end
end
