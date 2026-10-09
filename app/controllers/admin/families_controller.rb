require "csv"

class Admin::FamiliesController < Admin::BaseController
  def index
    @families = Family.order(:name)
  end

  def show
    @family = Family.find(params[:id])

    user_ids = @family.users.pluck(:id)
    @last_login_by_user = Session.where(user_id: user_ids).group(:user_id).maximum(:created_at)
    @sessions_count_by_user = Session.where(user_id: user_ids).group(:user_id).count

    @accounts = @family.accounts.order(:name)
    @accounts_count = @accounts.size
    @transactions_count = Entry.joins(:account).where(accounts: { family_id: @family.id }).count
    @chats_count = Chat.joins(:user).where(users: { family_id: @family.id }).count
    @messages_count = Message.joins(chat: :user).where(users: { family_id: @family.id }).count
    @last_activity_at = @last_login_by_user.values.max
  end

  def export
    families = Family.order(:name)
    family_ids = families.map(&:id)

    transactions_count_by_family = Entry.joins(:account).where(accounts: { family_id: family_ids }).group("accounts.family_id").count
    chats_count_by_family = Chat.joins(:user).where(users: { family_id: family_ids }).group("users.family_id").count
    member_count_by_family = User.where(family_id: family_ids).group(:family_id).count

    csv = CSV.generate do |rows|
      rows << [ "Family", "Created at", "Subscription status", "Members", "Transactions", "Chats" ]
      families.each do |family|
        rows << [
          family.name,
          family.created_at.iso8601,
          family.subscription&.status || "none",
          member_count_by_family[family.id] || 0,
          transactions_count_by_family[family.id] || 0,
          chats_count_by_family[family.id] || 0
        ]
      end
    end

    send_data csv, filename: "financespy-families-#{Date.current.iso8601}.csv", type: "text/csv"
  end

  def update
    family = Family.find(params[:id])

    old_business_mode = family.business_mode_enabled
    new_business_mode = ActiveRecord::Type::Boolean.new.cast(family_params[:business_mode_enabled])

    family.update!(business_mode_enabled: new_business_mode)

    if new_business_mode && !old_business_mode
      family.sync_inventory_account!

      account = family.accounts.find_by(name: "Mercadería", accountable_type: "OtherAsset")
      if account&.disabled?
        account.enable!
      end
    elsif !new_business_mode && old_business_mode
      account = family.accounts.find_by(name: "Mercadería", accountable_type: "OtherAsset")
      account&.disable!
    end

    redirect_to admin_families_path, notice: "Updated #{family.name}."
  end

  private
    def family_params
      params.require(:family).permit(:business_mode_enabled)
    end
end
