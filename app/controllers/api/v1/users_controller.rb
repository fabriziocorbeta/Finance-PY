# frozen_string_literal: true

class Api::V1::UsersController < Api::V1::BaseController
  before_action :ensure_read_scope, only: %i[reset_status nav_preferences]
  before_action :ensure_write_scope, except: %i[reset_status nav_preferences]
  before_action :ensure_admin, only: %i[reset reset_status]

  def reset
    family = current_resource_owner.family
    begin
      job = FamilyResetJob.perform_later(family)
    rescue StandardError => e
      Rails.logger.error "Failed to enqueue FamilyResetJob for family #{family.id}: #{e.message}"

      render json: {
        error: "reset_enqueue_failed",
        message: "Account reset could not be queued"
      }, status: :internal_server_error
      return
    end

    render json: {
      message: "Account reset has been initiated",
      status: "queued",
      job_id: job.job_id,
      family_id: family.id,
      status_url: api_v1_users_reset_status_path
    }
  end

  def reset_status
    family = current_resource_owner.family
    counts = reset_target_counts(family)
    reset_complete = counts.values.sum.zero?

    render json: {
      status: reset_complete ? "complete" : "data_remaining",
      family_id: family.id,
      reset_complete: reset_complete,
      counts: counts
    }
  end

  def update
    user = current_resource_owner

    if user.update(user_params)
      @family = user.family.reload
      @current_user = user.reload
      render "api/v1/family_settings/show"
    else
      render json: { error: "Failed to update user", details: user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def nav_preferences
    render json: { nav_item_order: current_resource_owner.nav_item_order }
  end

  def update_nav_preferences
    item_ids = params.require(:nav_item_order)

    unless item_ids.is_a?(Array) && item_ids.all? { |id| id.is_a?(String) }
      return render json: { error: "invalid_params", message: "nav_item_order must be an array of strings" }, status: :unprocessable_entity
    end

    current_resource_owner.update_nav_item_order(item_ids)
    render json: { nav_item_order: current_resource_owner.reload.nav_item_order }
  end

  def destroy
    user = current_resource_owner

    if user.deactivate
      Current.session&.destroy
      render json: { message: "Account has been deleted" }
    else
      render json: { error: "Failed to delete account", details: user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

    def user_params
      p = params.key?(:user) ? params.require(:user) : params

      family_attrs = %i[name currency country date_format timezone locale month_start_day]
      family_attrs.push(:moniker, :default_account_sharing) if user_admin?

      p.permit(
        :first_name, :last_name, :email, :theme, :locale,
        :onboarded_at, :set_onboarding_preferences_at, :set_onboarding_goals_at,
        goals: [],
        family_attributes: family_attrs
      )
    end

    def user_admin?
      current_resource_owner&.admin?
    end

    def ensure_write_scope
      authorize_scope!(:write)
    end

    def ensure_read_scope
      authorize_scope!(:read)
    end

    def ensure_admin
      return true if current_resource_owner&.admin?

      render_json({ error: "forbidden", message: "You are not authorized to perform this action" }, status: :forbidden)
      false
    end

    def reset_target_counts(family)
      {
        accounts: family.accounts.count,
        categories: family.categories.count,
        tags: family.tags.count,
        merchants: family.merchants.count,
        plaid_items: family.plaid_items.count,
        imports: family.imports.count,
        budgets: family.budgets.count
      }
    end
end
