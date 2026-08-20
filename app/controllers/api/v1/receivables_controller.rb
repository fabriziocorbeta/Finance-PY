# frozen_string_literal: true

class Api::V1::ReceivablesController < Api::V1::BaseController
  include Pagy::Backend

  before_action :ensure_read_scope

  def index
    @per_page = safe_per_page_param

    @pagy, @receivables = pagy(
      receivables_scope.order(created_at: :desc, id: :asc),
      page: safe_page_param,
      limit: @per_page
    )

    render :index
  rescue => e
    Rails.logger.error "ReceivablesController#index error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  def show
    @receivable = receivables_scope.find(params[:id])

    render :show
  rescue ActiveRecord::RecordNotFound
    render json: {
      error: "not_found",
      message: "Receivable not found"
    }, status: :not_found
  rescue => e
    Rails.logger.error "ReceivablesController#show error: #{e.message}"
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

    def receivables_scope
      # .accessible_by acota a las cuentas que el usuario posee o que le
      # compartieron via AccountShare. El scope por familia solo NO alcanza:
      # dentro de una misma familia una cuenta puede ser privada de otro
      # usuario. Mismo criterio que ya aplica el controller web equivalente
      # (app/controllers/receivables_controller.rb) y que accounts_controller.
      account_ids = current_resource_owner.family.accounts
                                          .visible
                                          .accessible_by(current_resource_owner)
                                          .where(accountable_type: "Receivable")
                                          .select(:accountable_id)
      Receivable.where(id: account_ids)
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
