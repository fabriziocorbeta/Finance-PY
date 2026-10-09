class Admin::DashboardController < Admin::BaseController
  def index
    @total_families = Family.count
    @total_users = User.count

    @new_families_7d = Family.where(created_at: 7.days.ago..).count
    @new_families_30d = Family.where(created_at: 30.days.ago..).count

    active_family_ids_7d = Session.where(created_at: 7.days.ago..).joins(:user).distinct.pluck("users.family_id")
    active_family_ids_30d = Session.where(created_at: 30.days.ago..).joins(:user).distinct.pluck("users.family_id")
    @active_families_7d = active_family_ids_7d.compact.uniq.count
    @active_families_30d = active_family_ids_30d.compact.uniq.count

    @subscription_counts = Subscription.group(:status).count
    @trials_expiring_7_days = Subscription
      .where(status: :trialing)
      .where(trial_ends_at: Time.current..7.days.from_now)
      .count

    @total_chats = Chat.count
    @families_using_chat_ever = Chat.joins(:user).distinct.count("users.family_id")
    @messages_7d = Message.where(created_at: 7.days.ago..).count
    @messages_30d = Message.where(created_at: 30.days.ago..).count
    @active_chat_families_7d = Message.where(created_at: 7.days.ago..)
      .joins(chat: :user).distinct.count("users.family_id")

    @recent_families = Family.order(created_at: :desc).limit(10)
  end
end
