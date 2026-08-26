# frozen_string_literal: true

class Api::V1::ReceivablesController < Api::V1::BaseController
  include Pagy::Backend

  before_action :ensure_read_scope, only: %i[index show]
  before_action :ensure_write_scope, only: %i[create update destroy]
  before_action :set_receivable, only: %i[show update destroy]

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
    render :show
  rescue => e
    Rails.logger.error "ReceivablesController#show error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  def create
    attrs = extracted_params
    total_amt = attrs[:total_amount]
    balance_amt = attrs[:balance].presence || total_amt || 0

    Account.transaction do
      @account = current_resource_owner.family.accounts.create_and_sync(
        {
          name: attrs[:name].presence || "Receivable",
          balance: balance_amt,
          currency: attrs[:currency].presence || current_resource_owner.family.currency,
          notes: attrs[:notes],
          owner: current_resource_owner,
          accountable_type: "Receivable",
          accountable_attributes: {
            total_amount: total_amt,
            installment_count: attrs[:installment_count],
            due_day: attrs[:due_day]
          }.compact
        }
      )
      @receivable = @account.accountable
    end

    if @receivable&.persisted? && @account&.persisted?
      render :show, status: :created
    else
      errors = []
      errors += @account.errors.full_messages if @account
      errors += @receivable.errors.full_messages if @receivable
      render json: {
        error: "validation_failed",
        message: "Receivable could not be created",
        errors: errors.uniq
      }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordInvalid => e
    render json: {
      error: "validation_failed",
      message: "Receivable could not be created",
      errors: e.record.errors.full_messages
    }, status: :unprocessable_entity
  rescue => e
    Rails.logger.error "ReceivablesController#create error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  def update
    attrs = extracted_params

    Account.transaction do
      account = @receivable.account

      if attrs[:balance].present? && account && attrs[:balance].to_d != account.balance
        result = account.set_current_balance(attrs[:balance].to_d)
        unless result.success?
          render json: {
            error: "validation_failed",
            message: "Receivable could not be updated",
            errors: [ result.error_message ]
          }, status: :unprocessable_entity
          raise ActiveRecord::Rollback
        end
      end

      if account
        account_updates = {}
        account_updates[:name] = attrs[:name] if attrs[:name].present?
        account_updates[:currency] = attrs[:currency] if attrs[:currency].present?
        account_updates[:notes] = attrs[:notes] if attrs.key?(:notes)

        if account_updates.any?
          account.update!(account_updates)
        end
      end

      receivable_updates = {}
      receivable_updates[:total_amount] = attrs[:total_amount] if attrs.key?(:total_amount)
      receivable_updates[:installment_count] = attrs[:installment_count] if attrs.key?(:installment_count)
      receivable_updates[:due_day] = attrs[:due_day] if attrs.key?(:due_day)

      if receivable_updates.any?
        @receivable.update!(receivable_updates)
      end
    end

    return if performed?

    @receivable.reload
    render :show
  rescue ActiveRecord::RecordInvalid => e
    render json: {
      error: "validation_failed",
      message: "Receivable could not be updated",
      errors: e.record.errors.full_messages
    }, status: :unprocessable_entity
  rescue => e
    Rails.logger.error "ReceivablesController#update error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  def destroy
    if @receivable.account
      @receivable.account.destroy!
    else
      @receivable.destroy!
    end

    render json: {
      message: "Receivable deleted successfully"
    }, status: :ok
  rescue => e
    Rails.logger.error "ReceivablesController#destroy error: #{e.message}"
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

    def set_receivable
      @receivable = receivables_scope.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: {
        error: "not_found",
        message: "Receivable not found"
      }, status: :not_found
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

    def extracted_params
      raw = if params[:receivable].present?
              params[:receivable]
            elsif params[:account].present?
              params[:account]
            else
              params
            end

      receivable_attrs = raw[:accountable_attributes] || {}

      {
        name: raw[:name],
        balance: raw[:balance],
        currency: raw[:currency],
        notes: raw[:notes],
        total_amount: raw[:total_amount] || receivable_attrs[:total_amount],
        installment_count: raw[:installment_count] || receivable_attrs[:installment_count],
        due_day: raw[:due_day] || receivable_attrs[:due_day]
      }
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
