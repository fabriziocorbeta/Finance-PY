# frozen_string_literal: true

class Api::V1::RulesController < Api::V1::BaseController
  include Pagy::Backend

  BOOLEAN_FILTERS = {
    "true" => true,
    "1" => true,
    "false" => false,
    "0" => false
  }.freeze
  RESOURCE_TYPES = %w[transaction].freeze

  before_action :ensure_read_scope, only: %i[index show registry]
  before_action :ensure_write_scope, only: %i[create update destroy]
  before_action :set_rule, only: %i[show update destroy]

  # GET /api/v1/rules/registry?resource_type=transaction
  # Returns the available condition filters and action executors (with their
  # operators/options and Spanish labels) so clients can build a picker UI
  # instead of hardcoding this registry, which is Ruby-class-driven.
  def registry
    return render_invalid_resource_type_filter if invalid_resource_type_filter?

    resource_type = params[:resource_type].presence || "transaction"
    transient_rule = current_resource_owner.family.rules.build(resource_type: resource_type)

    render json: {
      filters: transient_rule.registry.condition_filters.map { |filter| localized_filter_json(filter) },
      executors: transient_rule.registry.action_executors.map { |executor| localized_executor_json(executor) }
    }
  end

  def index
    return render_invalid_resource_type_filter if invalid_resource_type_filter?

    @per_page = safe_per_page_param
    rules_query = current_resource_owner.family.rules
      .includes(:actions, conditions: :sub_conditions)
      .order(:created_at, :id)

    rules_query = rules_query.where(resource_type: params[:resource_type]) if params[:resource_type].present?
    if params[:active].present?
      active = parse_boolean_filter(params[:active])
      return if performed?

      rules_query = rules_query.where(active: active)
    end

    @pagy, @rules = pagy(
      rules_query,
      page: safe_page_param,
      limit: @per_page
    )

    render :index
  end

  def show
    render :show
  end

  def create
    @rule = current_resource_owner.family.rules.new(rule_params)

    if @rule.save
      render :show, status: :created
    else
      render json: {
        error: "validation_failed",
        message: "Rule could not be created",
        errors: @rule.errors.full_messages
      }, status: :unprocessable_entity
    end
  rescue => e
    Rails.logger.error "RulesController#create error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  def update
    if @rule.update(rule_params)
      render :show
    else
      render json: {
        error: "validation_failed",
        message: "Rule could not be updated",
        errors: @rule.errors.full_messages
      }, status: :unprocessable_entity
    end
  rescue => e
    Rails.logger.error "RulesController#update error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  def destroy
    @rule.destroy!
    head :no_content
  rescue => e
    Rails.logger.error "RulesController#destroy error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  private

    def set_rule
      @rule = current_resource_owner.family.rules
        .includes(:actions, conditions: :sub_conditions)
        .find(params[:id])
    end

    def ensure_read_scope
      authorize_scope!(:read)
    end

    def ensure_write_scope
      authorize_scope!(:read_write)
    end

    def rule_params
      params.require(:rule).permit(
        :name, :resource_type, :active, :effective_date,
        conditions_attributes: [
          :id, :condition_type, :operator, :value, :_destroy,
          sub_conditions_attributes: [ :id, :condition_type, :operator, :value, :_destroy ]
        ],
        actions_attributes: [ :id, :action_type, :value, :_destroy ]
      )
    end

    # NOTE: never pass filter.label/executor.label as an I18n `default:` -
    # Rails evaluates that argument eagerly even when the translation is
    # found, and Rule::ActionExecutor::AutoCategorize#label makes a real
    # (billed) OpenAI call to estimate a per-run cost estimate. Use a plain
    # humanized key as the fallback instead - it never touches the model.
    def localized_filter_json(filter)
      {
        type: filter.type,
        key: filter.key,
        label: I18n.t("rules.condition_filters.#{filter.key}.label", default: filter.key.humanize),
        operators: (filter.operators || []).map { |(_label, value)| [ I18n.t("rules.operators.#{value}", default: _label), value ] },
        options: filter.options,
        number_step: filter.number_step
      }
    end

    def localized_executor_json(executor)
      {
        type: executor.type,
        key: executor.key,
        label: I18n.t("rules.action_executors.#{executor.key}.label", default: executor.key.humanize),
        options: executor.options
      }
    end

    def parse_boolean_filter(value)
      normalized = value.to_s.downcase
      return BOOLEAN_FILTERS[normalized] if BOOLEAN_FILTERS.key?(normalized)

      render_validation_error("active must be one of: true, false, 1, 0")
      nil
    end

    def invalid_resource_type_filter?
      params[:resource_type].present? && !params[:resource_type].in?(RESOURCE_TYPES)
    end

    def render_invalid_resource_type_filter
      render_validation_error("resource_type must be one of: #{RESOURCE_TYPES.join(", ")}")
    end
end
