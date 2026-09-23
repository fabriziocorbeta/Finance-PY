class PurchaseOrder < ApplicationRecord
  include Encryptable

  # User-entered free text: encrypted at rest (owner/DB-leak protection). Not queried in SQL.
  if encryption_ready?
    encrypts :notes
  end

  belongs_to :family
  belongs_to :account
  belongs_to :entry, optional: true
  has_many :purchase_order_items, dependent: :destroy

  enum :status, { draft: "draft", received: "received", cancelled: "cancelled" }, default: "draft"
  enum :currency, { pyg: "pyg", usd: "usd" }, default: "pyg"

  validates :order_number, presence: true, uniqueness: { scope: :family_id }
  validate :account_belongs_to_family
  validate :status_cannot_be_changed_directly, on: :update

  before_validation :assign_order_number, on: :create
  before_destroy :prevent_destroy_unless_draft

  accepts_nested_attributes_for :purchase_order_items, allow_destroy: true, reject_if: proc { |attributes| attributes["product_id"].blank? }

  attr_accessor :allow_status_change

  def total
    purchase_order_items.sum(&:subtotal)
  end

  # See Sale#complete! for why with_lock + reload + idempotency check (instead
  # of plain `transaction do`) is what makes double-clicking receive!/cancel!
  # (or two concurrent requests) safe: the second caller blocks on the row
  # lock until the first commits, then observes the final status and no-ops.
  def receive!
    with_lock do
      next if received?

      unless draft?
        errors.add(:status, "must be draft to receive")
        raise ActiveRecord::RecordInvalid.new(self)
      end

      locked_products = lock_products_for(purchase_order_items)

      purchase_order_items.each do |item|
        ProductStockMovement.create!(
          product: locked_products.fetch(item.product_id),
          reason: "entrada",
          quantity_delta: item.quantity
        )
      end

      begin
        @allow_status_change = true
        update!(status: "received")
      ensure
        @allow_status_change = false
      end

      create_associated_entry
    end
  end

  def cancel!
    with_lock do
      next if cancelled?

      unless draft? || received?
        errors.add(:status, "must be draft or received to cancel")
        raise ActiveRecord::RecordInvalid.new(self)
      end

      if received?
        locked_products = lock_products_for(purchase_order_items)

        purchase_order_items.each do |item|
          product = locked_products.fetch(item.product_id)
          if product.stock < item.quantity
            errors.add(:base, "Insufficient stock for #{product.name}")
            raise ActiveRecord::RecordInvalid.new(self)
          end
        end

        purchase_order_items.each do |item|
          ProductStockMovement.create!(
            product: locked_products.fetch(item.product_id),
            reason: "salida",
            quantity_delta: -item.quantity
          )
        end
      end

      begin
        @allow_status_change = true
        update!(status: "cancelled")
      ensure
        @allow_status_change = false
      end

      destroy_associated_entry
    end
  end

  private

    # See Sale#lock_products_for: fixed id order avoids cross-model deadlocks
    # (a Sale and a PurchaseOrder locking the same two products in opposite
    # order), and the lock makes the stock check in cancel! (below) safe from
    # a concurrent update on the same product.
    def lock_products_for(items)
      product_ids = items.map(&:product_id).uniq.sort
      Product.where(id: product_ids).order(:id).lock.index_by(&:id)
    end

    def create_associated_entry
      purchase_category = family.categories.find_or_create_by!(name: "Compras") do |category|
        category.color = "#f97316"
        category.lucide_icon = "shopping-bag"
      end
      transaction_entryable = Transaction.new(category: purchase_category)
      entry_record = account.entries.create!(
        entryable: transaction_entryable,
        name: "Compra ##{order_number}#{supplier_name.present? ? " - #{supplier_name}" : ""}",
        date: Date.current,
        amount: total_in_account_currency,
        currency: account.currency
      )
      update_column(:entry_id, entry_record.id)
      entry_record.sync_account_later
    end

    # `total` is denominated in the purchase order's own currency
    # (user-selected on the form, independent from the account's currency).
    # Convert it to the account's currency before recording the entry so a
    # USD order on a PYG account (or vice versa) doesn't silently post the
    # raw number under the wrong currency. Mirrors the Money#exchange_to +
    # rescue fallback pattern used for cross-currency amounts elsewhere
    # (e.g. ReportsController).
    def total_in_account_currency
      return total if currency.to_s.casecmp?(account.currency.to_s)

      Money.new(total, currency).exchange_to(account.currency).amount
    rescue Money::ConversionError
      total
    end

    def destroy_associated_entry
      if entry
        entry_to_remove = entry
        update_column(:entry_id, nil)
        entry_to_remove.destroy!
        entry_to_remove.sync_account_later
      end
    end

    def account_belongs_to_family
      return if account.nil? || family.nil?
      errors.add(:account, "must belong to the same family") unless account.family_id == family_id
    end

    def assign_order_number
      if order_number.blank? && family.present?
        self.order_number = family.purchase_orders.maximum(:order_number).to_i + 1
      end
    end

    def status_cannot_be_changed_directly
      if status_changed? && !@allow_status_change
        errors.add(:status, "cannot be changed directly. Use receive! or cancel! instead.")
      end
    end

    def prevent_destroy_unless_draft
      unless draft?
        errors.add(:base, "Cannot delete a purchase order that is not in draft status. Cancel it first.")
        throw :abort
      end
    end
end
