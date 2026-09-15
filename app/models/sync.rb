class Sync < ApplicationRecord
  # We run a cron that marks any syncs that have not been resolved in 24 hours as "stale"
  # Syncs often become stale when new code is deployed and the worker restarts
  STALE_AFTER = 24.hours

  # The max time that a sync will show in the UI (after 5 minutes)
  VISIBLE_FOR = 5.minutes

  include AASM

  Error = Class.new(StandardError)

  belongs_to :syncable, polymorphic: true

  belongs_to :parent, class_name: "Sync", optional: true
  has_many :children, class_name: "Sync", foreign_key: :parent_id, dependent: :destroy

  before_validation :denormalize_family_id, on: :create

  scope :ordered, -> { order(created_at: :desc) }
  scope :incomplete, -> { where("syncs.status IN (?)", %w[pending syncing]) }
  scope :visible, -> { incomplete.where("syncs.created_at > ?", VISIBLE_FOR.ago) }

  after_commit :update_family_sync_timestamp

  serialize :sync_stats, coder: JSON

  validate :window_valid

  # Sync state machine
  aasm column: :status, timestamps: true do
    state :pending, initial: true
    state :syncing
    state :completed
    state :failed
    state :stale

    after_all_transitions :handle_transition

    event :start, after_commit: :handle_start_transition do
      transitions from: :pending, to: :syncing
    end

    event :complete, after_commit: :handle_completion_transition do
      transitions from: :syncing, to: :completed
    end

    event :fail do
      transitions from: :syncing, to: :failed
    end

    # Marks a sync that never completed within the expected time window
    event :mark_stale do
      transitions from: %i[pending syncing], to: :stale
    end
  end

  class << self
    def clean
      incomplete.where("syncs.created_at < ?", STALE_AFTER.ago).find_each(&:mark_stale!)
    end
  end

  def perform
    Rails.logger.tagged("Sync", id, syncable_type, syncable_id) do
      # This can happen on server restarts or if Sidekiq enqueues a duplicate job
      unless may_start?
        Rails.logger.warn("Sync #{id} is not in a valid state (#{aasm.from_state}) to start.  Skipping sync.")
        return
      end

      # Guard: syncable may have been deleted while job was queued
      unless syncable.present?
        Rails.logger.warn("Sync #{id} - syncable #{syncable_type}##{syncable_id} no longer exists. Marking as failed.")
        start! if may_start?
        fail!
        update(error: "Syncable record was deleted")
        return
      end

      # Guard: syncable may be scheduled for deletion
      if syncable.respond_to?(:scheduled_for_deletion?) && syncable.scheduled_for_deletion?
        Rails.logger.warn("Sync #{id} - syncable #{syncable_type}##{syncable_id} is scheduled for deletion. Skipping sync.")
        start! if may_start?
        fail!
        update(error: "Syncable record is scheduled for deletion")
        return
      end

      start!

      begin
        syncable.perform_sync(self)
      rescue => e
        fail!
        update(error: e.message)
        report_error(e)
      ensure
        finalize_if_all_children_finalized
      end
    end
  end

  # Finalizes the current sync AND parent (if it exists)
  def finalize_if_all_children_finalized
    Sync.transaction do
      lock!

      # If this is the "parent" and there are still children running, don't finalize.
      return unless all_children_finalized?

      if syncing?
        if has_failed_children?
          fail!
        else
          complete!
        end
      end

      # If we make it here, the sync is finalized.  Run post-sync, regardless of failure/success.
      perform_post_sync
    end

    # If this sync has a parent, try to finalize it so the child status propagates up the chain.
    parent&.finalize_if_all_children_finalized
  end

  # If a sync is pending, we can adjust the window if new syncs are created with a wider window.
  def expand_window_if_needed(new_window_start_date, new_window_end_date)
    return unless pending?
    return if self.window_start_date.nil? && self.window_end_date.nil? # already as wide as possible

    earliest_start_date = if self.window_start_date && new_window_start_date
      [ self.window_start_date, new_window_start_date ].min
    else
      nil
    end

    latest_end_date = if self.window_end_date && new_window_end_date
      [ self.window_end_date, new_window_end_date ].max
    else
      nil
    end

    update(
      window_start_date: earliest_start_date,
      window_end_date: latest_end_date
    )
  end

  # Pública a propósito: ActiveJobRowLevelSecurity#extract_family usa
  # `arg.respond_to?(:family)` para detectar la family de un job y setear el
  # contexto RLS antes de correr -- respond_to? no ve métodos privados, así
  # que si este método estuviera en la sección private de abajo (como estaba
  # antes), esa detección fallaba en silencio para todo SyncJob.
  #
  # Usa family_id (denormalizado, poblado en denormalize_family_id más abajo)
  # en vez de `syncable.family` como primera opción: en el momento en que
  # ActiveJobRowLevelSecurity llama a este método, el contexto RLS TODAVÍA NO
  # está seteado -- es justo lo que este método ayuda a decidir. `syncable`
  # casi siempre apunta a una tabla con FORCE ROW LEVEL SECURITY (accounts,
  # simplefin_items, etc), así que resolverlo acá es la misma query que RLS
  # bloquea sin contexto (huevo y gallina). `families` no tiene RLS, así que
  # leer por family_id sí funciona sin contexto previo. El fallback a
  # `syncable.family` solo cubre syncs históricos creados antes de esta
  # columna (ver migración) -- para esos, el detector de family del job
  # simplemente vuelve a fallar como antes, no hay forma de evitarlo sin
  # dato denormalizado.
  def family
    if family_id.present?
      Family.find_by(id: family_id)
    elsif syncable.is_a?(Family)
      syncable
    else
      syncable.family
    end
  end

  private
    # Corre en request-time (creación siempre pasa por `syncable.syncs.create!`
    # o `Sync.create!(syncable: x)`, con `syncable` ya cargado en memoria y el
    # contexto RLS de la request ya seteado por Authentication), así que
    # resolver family acá nunca pega contra el problema de huevo y gallina que
    # sí existe más tarde, en el job.
    def denormalize_family_id
      return if family_id.present? || syncable.nil?
      self.family_id = syncable.is_a?(Family) ? syncable.id : syncable.family&.id
    end

    def log_status_change
      Rails.logger.info("changing from #{aasm.from_state} to #{aasm.to_state} (event: #{aasm.current_event})")
    end

    def has_failed_children?
      children.failed.any?
    end

    def all_children_finalized?
      children.incomplete.empty?
    end

    def perform_post_sync
      Rails.logger.info("Performing post-sync for #{syncable_type} (#{syncable.id})")
      syncable.perform_post_sync
      syncable.broadcast_sync_complete
    rescue => e
      Rails.logger.error("Error performing post-sync for #{syncable_type} (#{syncable.id}): #{e.message}")
      report_error(e)
    end

    def report_error(error)
      Sentry.capture_exception(error) do |scope|
        scope.set_tags(sync_id: id)
      end
    end

    def report_warnings
      todays_sync_count = syncable.syncs.where(created_at: Date.current.all_day).count

      if todays_sync_count > 10
        Sentry.capture_exception(
          Error.new("#{syncable_type} (#{syncable.id}) has exceeded 10 syncs today (count: #{todays_sync_count})"),
          level: :warning
        )
      end
    end

    def handle_start_transition
      report_warnings
    end

    def handle_transition
      log_status_change
    end

    def handle_completion_transition
      family.touch(:latest_sync_completed_at)
    end

    def window_valid
      if window_start_date && window_end_date && window_start_date > window_end_date
        errors.add(:window_end_date, "must be greater than window_start_date")
      end
    end

    def update_family_sync_timestamp
      family.touch(:latest_sync_activity_at)
    end
end
