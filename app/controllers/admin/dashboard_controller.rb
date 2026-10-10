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

    # Full families table, like the ERP admin panel's single-page "Usuarios
    # del Sistema" table -- members, balance, plan and last activity all
    # visible together, not just a name/date/status summary needing a click
    # into each family to see any of it.
    @families = Family.order(created_at: :desc)
    family_ids = @families.map(&:id)

    @member_count_by_family = User.where(family_id: family_ids).group(:family_id).count
    @last_activity_by_family = Session.where(created_at: 90.days.ago..)
      .joins(:user).group("users.family_id").maximum(:created_at)

    # Summed only within each family's own primary currency -- accounts in a
    # different currency exist (multi-currency families) but naively adding
    # raw balances across currencies would produce a meaningless number, so
    # those are left out of this total rather than silently misrepresented.
    balances = Account.where(family_id: family_ids)
      .where("accounts.currency = families.currency")
      .joins(:family)
      .group(:family_id, :currency).sum(:balance)
    @balance_by_family = balances.each_with_object({}) do |((fam_id, currency), sum), h|
      h[fam_id] = Money.new(sum, currency)
    end

    # Bucketed in Ruby, not via SQL `group("DATE(created_at)")` -- that
    # truncates using Postgres' *session* timezone, which doesn't
    # necessarily match Rails' app timezone (Time.current/.to_date below).
    # Near either timezone's midnight boundary the two can disagree on what
    # "today" even is, silently dropping a just-created family from every
    # bucket (confirmed flaky in CI). Only 30 days of rows, so grouping
    # in-memory is cheap and removes the ambiguity entirely.
    signups_by_day = Family.where(created_at: 30.days.ago.beginning_of_day..)
      .pluck(:created_at).group_by(&:to_date).transform_values(&:size)
    @signup_counts_30d = (0..29).map do |days_ago|
      signups_by_day[days_ago.days.ago.to_date] || 0
    end.reverse
  end
end
