# frozen_string_literal: true

class Api::V1::GoalsController < Api::V1::BaseController
  include Pagy::Backend

  before_action :ensure_read_scope, only: %i[index show]
  before_action :ensure_write_scope, only: %i[create update destroy]
  before_action :set_goal, only: %i[show update destroy]

  def index
    @per_page = safe_per_page_param

    @pagy, @goals = pagy(
      current_resource_owner.family.goals.order(created_at: :desc, id: :asc),
      page: safe_page_param,
      limit: @per_page
    )

    render :index
  rescue => e
    Rails.logger.error "GoalsController#index error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  def show
    render :show
  rescue => e
    Rails.logger.error "GoalsController#show error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  def create
    raw_params = goal_raw_params
    goal_attrs = extract_goal_params(raw_params)

    @goal = current_resource_owner.family.goals.new(goal_attrs)
    process_account_links(@goal, raw_params)

    if @goal.currency.blank?
      first_account = @goal.goal_accounts.map(&:account).compact.first
      @goal.currency = first_account&.currency || current_resource_owner.family.primary_currency_code
    end

    if @goal.save
      render :show, status: :created
    else
      render json: {
        error: "validation_failed",
        message: "Goal could not be created",
        errors: @goal.errors.full_messages
      }, status: :unprocessable_entity
    end
  rescue ActionController::ParameterMissing => e
    render json: {
      error: "bad_request",
      message: e.message
    }, status: :bad_request
  rescue => e
    Rails.logger.error "GoalsController#create error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  def update
    raw_params = goal_raw_params
    goal_attrs = extract_goal_params(raw_params)

    Goal.transaction do
      @goal.assign_attributes(goal_attrs) if goal_attrs.present?
      sync_account_links(@goal, raw_params)

      if @goal.save
        render :show, status: :ok
      else
        render json: {
          error: "validation_failed",
          message: "Goal could not be updated",
          errors: @goal.errors.full_messages
        }, status: :unprocessable_entity
        raise ActiveRecord::Rollback
      end
    end
  rescue ActionController::ParameterMissing => e
    render json: {
      error: "bad_request",
      message: e.message
    }, status: :bad_request
  rescue => e
    Rails.logger.error "GoalsController#update error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  def destroy
    unless @goal.archived?
      render json: {
        error: "validation_failed",
        message: "Goal must be archived before it can be deleted",
        errors: [ "Goal must be archived before it can be deleted" ]
      }, status: :unprocessable_entity
      return
    end

    @goal.destroy!
    head :no_content
  rescue => e
    Rails.logger.error "GoalsController#destroy error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  private

    def set_goal
      @goal = current_resource_owner.family.goals.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: {
        error: "not_found",
        message: "Goal not found"
      }, status: :not_found
    end

    def ensure_read_scope
      authorize_scope!(:read)
    end

    def ensure_write_scope
      authorize_scope!(:write)
    end

    def goal_raw_params
      params.key?(:goal) ? params.require(:goal) : params
    end

    def extract_goal_params(raw_params)
      raw_params.permit(:name, :target_amount, :currency, :target_date, :color, :icon, :notes, :progress_basis, :state).to_h.symbolize_keys
    end

    def process_account_links(goal, raw_params)
      if raw_params[:goal_accounts_attributes].present?
        attrs_list = raw_params[:goal_accounts_attributes]
        attrs_list = attrs_list.values if attrs_list.is_a?(Hash) || attrs_list.respond_to?(:values)
        attrs_list.each do |ga_attr|
          acc_id = ga_attr[:account_id] || ga_attr["account_id"]
          allocated = ga_attr[:allocated_amount] || ga_attr["allocated_amount"]
          account = current_resource_owner.family.accounts.find_by(id: acc_id) if acc_id.present?
          goal.goal_accounts.build(account: account, allocated_amount: allocated) if account
        end
      elsif raw_params.key?(:account_ids)
        account_ids = Array(raw_params[:account_ids]).reject(&:blank?)
        accounts = current_resource_owner.family.accounts.where(id: account_ids).to_a
        allocations = submitted_allocations(raw_params)
        accounts.each do |account|
          goal.goal_accounts.build(account: account, allocated_amount: allocations[account.id.to_s])
        end
      end
    end

    def sync_account_links(goal, raw_params)
      if raw_params.key?(:account_ids)
        account_ids = Array(raw_params[:account_ids]).reject(&:blank?)
        accounts = current_resource_owner.family.accounts.where(id: account_ids).to_a
        allocations = submitted_allocations(raw_params)

        desired_ids = accounts.map(&:id).to_set
        goal.goal_accounts.each do |ga|
          unless desired_ids.include?(ga.account_id)
            ga.mark_for_destruction
          end
        end

        accounts.each do |account|
          existing = goal.goal_accounts.reject(&:marked_for_destruction?).find { |ga| ga.account_id == account.id }
          if existing
            existing.allocated_amount = allocations[account.id.to_s] if allocations.key?(account.id.to_s)
          else
            goal.goal_accounts.build(account: account, allocated_amount: allocations[account.id.to_s])
          end
        end
      elsif raw_params[:goal_accounts_attributes].present?
        attrs_list = raw_params[:goal_accounts_attributes]
        attrs_list = attrs_list.values if attrs_list.is_a?(Hash) || attrs_list.respond_to?(:values)
        attrs_list.each do |ga_attr|
          ga_id = ga_attr[:id] || ga_attr["id"]
          acc_id = ga_attr[:account_id] || ga_attr["account_id"]
          allocated = ga_attr[:allocated_amount] || ga_attr["allocated_amount"]
          destroy_flag = ActiveModel::Type::Boolean.new.cast(ga_attr[:_destroy] || ga_attr["_destroy"])

          if ga_id.present?
            existing = goal.goal_accounts.find { |ga| ga.id == ga_id }
            if existing
              if destroy_flag
                existing.mark_for_destruction
              else
                existing.allocated_amount = allocated if ga_attr.key?(:allocated_amount) || ga_attr.key?("allocated_amount")
              end
            end
          elsif acc_id.present?
            account = current_resource_owner.family.accounts.find_by(id: acc_id)
            if account
              existing = goal.goal_accounts.reject(&:marked_for_destruction?).find { |ga| ga.account_id == account.id }
              if existing
                if destroy_flag
                  existing.mark_for_destruction
                else
                  existing.allocated_amount = allocated
                end
              elsif !destroy_flag
                goal.goal_accounts.build(account: account, allocated_amount: allocated)
              end
            end
          end
        end
      end
    end

    def submitted_allocations(raw_params)
      raw = raw_params[:allocations]
      return {} if raw.blank?

      hash = raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw
      hash.each_with_object({}) do |(account_id, amount), memo|
        memo[account_id.to_s] = amount.to_s.strip.presence
      end
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
