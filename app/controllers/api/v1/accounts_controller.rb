# frozen_string_literal: true

class Api::V1::AccountsController < Api::V1::BaseController
  include Pagy::Backend

  # Property y Receivable quedan afuera a propósito: Property tiene un alta
  # multi-paso (draft -> balances -> address -> activate) que no encaja en
  # este endpoint genérico, y Receivable ya tiene su propio flujo nativo
  # aparte (ver PR #102). Estos 7 cubren los tipos "simples" -- mismos
  # campos extra por tipo que ya usan los controllers web
  # (depositories/credit_cards/investments/vehicles/loans/cryptos/
  # other_assets_controller.rb via AccountableResource).
  PERMITTED_ACCOUNTABLE_ATTRS = {
    "Depository" => [],
    "Investment" => [ :subtype ],
    "Crypto" => [ :subtype, :tax_treatment ],
    "Vehicle" => [ :make, :model, :year, :mileage_value, :mileage_unit ],
    "OtherAsset" => [],
    "CreditCard" => [ :available_credit, :minimum_payment, :apr, :annual_fee, :expiration_date ],
    "Loan" => [ :subtype, :rate_type, :interest_rate, :term_months, :initial_balance ]
  }.freeze

  # Ensure proper scope authorization for read access
  before_action :ensure_read_scope, only: %i[index show balance_series]
  before_action :ensure_write_scope, only: :create

  def create
    accountable_type = params.dig(:account, :accountable_type).presence || params[:accountable_type].to_s

    unless PERMITTED_ACCOUNTABLE_ATTRS.key?(accountable_type)
      return render json: {
        error: "unsupported_accountable_type",
        message: "accountable_type must be one of: #{PERMITTED_ACCOUNTABLE_ATTRS.keys.join(', ')}"
      }, status: :unprocessable_entity
    end

    opening_balance_date = begin
      create_params[:opening_balance_date].presence&.to_date
    rescue Date::Error
      nil
    end || (Time.zone.today - 2.years)

    account = current_resource_owner.family.accounts.create_and_sync(
      create_params.except(:opening_balance_date).merge(accountable_type: accountable_type, owner: current_resource_owner),
      opening_balance_date: opening_balance_date
    )
    account.lock_saved_attributes!

    @account = account
    render :show, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: {
      error: "validation_failed",
      message: "Account could not be created",
      errors: e.record.errors.full_messages
    }, status: :unprocessable_entity
  rescue => e
    Rails.logger.error "AccountsController#create error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  def index
    @per_page = safe_per_page_param

    @pagy, @accounts = pagy(
      accounts_scope.alphabetically,
      page: safe_page_param,
      limit: @per_page
    )

    render :index
  rescue => e
    Rails.logger.error "AccountsController#index error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  def show
    unless valid_uuid?(params[:id])
      render json: {
        error: "not_found",
        message: "Account not found"
      }, status: :not_found
      return
    end

    @account = accounts_scope.find(params[:id])

    render :show
  rescue ActiveRecord::RecordNotFound
    render json: {
      error: "not_found",
      message: "Account not found"
    }, status: :not_found
  rescue => e
    Rails.logger.error "AccountsController#show error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  ALLOWED_PERIOD_KEYS = %w[last_30_days last_90_days last_365_days current_year all_time].freeze

  def balance_series
    unless valid_uuid?(params[:id])
      render json: {
        error: "not_found",
        message: "Account not found"
      }, status: :not_found
      return
    end

    @account = accounts_scope.find(params[:id])
    @period = resolve_period

    cache_key = @account.family.build_cache_key(
      "#{@account.id}_balance_series_#{@period.key}_#{Account::Chartable::SPARKLINE_CACHE_VERSION}",
      invalidate_on_data_updates: true
    )

    @series = Rails.cache.fetch(cache_key, expires_in: 24.hours) do
      @account.balance_series(period: @period)
    end

    render :balance_series
  rescue ActiveRecord::RecordNotFound
    render json: {
      error: "not_found",
      message: "Account not found"
    }, status: :not_found
  rescue => e
    Rails.logger.error "AccountsController#balance_series error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  private

    def resolve_period
      if params[:period].present? && ALLOWED_PERIOD_KEYS.include?(params[:period])
        Period.from_key(params[:period])
      else
        Period.last_30_days
      end
    rescue Period::InvalidKeyError
      Period.last_30_days
    end

    def ensure_read_scope
      authorize_scope!(:read)
    end

    def ensure_write_scope
      authorize_scope!(:write)
    end

    def create_params
      accountable_type = params.dig(:account, :accountable_type).presence || params[:accountable_type].to_s
      permitted_extra = PERMITTED_ACCOUNTABLE_ATTRS.fetch(accountable_type, [])
      raw = params.key?(:account) ? params.require(:account) : params

      raw.permit(
        :name, :balance, :subtype, :currency, :opening_balance_date,
        :institution_name, :institution_domain, :notes,
        accountable_attributes: permitted_extra
      )
    end

    def accounts_scope
      scope = current_resource_owner.family.accounts
                                    .accessible_by(current_resource_owner)
                                    .includes(:accountable, account_providers: :provider)
      include_disabled_accounts? ? scope : scope.visible
    end

    def include_disabled_accounts?
      ActiveModel::Type::Boolean.new.cast(params[:include_disabled])
    end

    def valid_uuid?(value)
      value.to_s.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i)
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
