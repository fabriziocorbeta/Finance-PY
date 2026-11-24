class FuelLog < ApplicationRecord
  include Encryptable

  # User-entered free text: encrypted at rest (owner/DB-leak protection). Not queried in SQL.
  if encryption_ready?
    encrypts :notes
  end

  belongs_to :fleet_vehicle
  belongs_to :account
  belongs_to :entry, optional: true

  has_many :fuel_log_lines, dependent: :destroy
  accepts_nested_attributes_for :fuel_log_lines, allow_destroy: true, reject_if: :all_blank

  before_validation :sync_totals_from_lines

  validates :liters, presence: true, numericality: { greater_than: 0 }
  validates :cost, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :odometer, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :logged_at, presence: true
  validate :must_have_at_least_one_fuel_log_line
  validate :account_belongs_to_family

  after_create_commit :create_associated_entry
  after_update_commit :update_associated_entry
  before_destroy :store_account_for_sync
  after_destroy_commit :destroy_associated_entry

  private

    def sync_totals_from_lines
      active_lines = fuel_log_lines.reject(&:marked_for_destruction?)
      return if active_lines.empty?

      self.liters = active_lines.sum(BigDecimal("0")) { |line| BigDecimal(line.liters.to_s) }
      self.cost = active_lines.sum(BigDecimal("0")) { |line| BigDecimal(line.cost.to_s) }
    end

    def must_have_at_least_one_fuel_log_line
      active_lines = fuel_log_lines.reject(&:marked_for_destruction?)
      if active_lines.empty?
        errors.add(:base, "Debe registrar al menos un tipo de combustible")
      end
    end

    def account_belongs_to_family
      if account && fleet_vehicle && account.family_id != fleet_vehicle.family_id
        errors.add(:account, "must belong to the same family as the vehicle")
      end
    end

    def create_associated_entry
      return if entry_id.present?

      entry = find_matching_wallet_entry
      if entry
        entry.update!(
          name: "Combustible - #{fleet_vehicle.plate}",
          date: logged_at
        )
        if entry.entryable.is_a?(Transaction) && entry.entryable.category_id != fuel_category.id
          entry.entryable.update!(category: fuel_category)
        end
      else
        transaction = Transaction.new(category: fuel_category)
        entry = account.entries.create!(
          entryable: transaction,
          name: "Combustible - #{fleet_vehicle.plate}",
          date: logged_at,
          amount: cost,
          currency: account.currency
        )
      end
      update_column(:entry_id, entry.id)

      entry.sync_account_later
    end

    # Reconcile with an automatic Google Wallet / bank notification capture
    # that already recorded this same fuel purchase (+/-1 day, same account
    # and cost) so logging it in Flota does not create a duplicate entry.
    def find_matching_wallet_entry
      account.entries
        .left_outer_joins(:fuel_log)
        .where(
          source: "google_play",
          date: (logged_at - 1.day)..(logged_at + 1.day),
          amount: cost,
          fuel_logs: { id: nil }
        )
        .order(created_at: :desc)
        .first
    end

    # Cargas de combustible de Flota siempre van a esta categoría fija: no tiene
    # sentido pasar por auto-categorización (por regla o IA) para algo que ya
    # sabemos qué es en el momento de crearlo.
    def fuel_category
      account.family.categories.find_or_create_by!(name: "Combustible") do |category|
        category.color = "#f59e0b"
        category.lucide_icon = "fuel"
      end
    end

    def update_associated_entry
      return unless entry

      if saved_change_to_cost? || saved_change_to_logged_at? || saved_change_to_account_id?
        previous_account_id = saved_change_to_account_id&.first
        previous_date = entry.date

        entry.update!(
          account: account,
          amount: cost,
          date: logged_at,
          currency: account.currency
        )
        entry.sync_account_later

        if previous_account_id.present? && previous_account_id != account_id
          previous_account = Account.find_by(id: previous_account_id)
          previous_account&.sync_later(window_start_date: previous_date, window_end_date: Date.current)
        end
      end
    end

    def store_account_for_sync
      @account_for_sync = account
    end

    def destroy_associated_entry
      if entry
        entry.destroy!
        entry.sync_account_later
      end
    end
end
