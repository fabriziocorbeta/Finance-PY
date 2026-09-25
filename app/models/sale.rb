class Sale < ApplicationRecord
  include Encryptable

  # User-entered free text: encrypted at rest (owner/DB-leak protection). Not queried in SQL.
  if encryption_ready?
    encrypts :notes
    encrypts :delivery_address
  end

  belongs_to :family
  belongs_to :account
  belongs_to :entry, optional: true
  has_many :sale_items, dependent: :destroy
  accepts_nested_attributes_for :sale_items, allow_destroy: true, reject_if: proc { |attributes| attributes["product_id"].blank? }

  enum :status, { draft: "draft", completed: "completed", cancelled: "cancelled" }, default: "draft"
  enum :currency, { pyg: "pyg", usd: "usd" }, default: "pyg"

  validates :sale_number, presence: true, uniqueness: { scope: :family_id }
  validate :account_belongs_to_family
  validate :status_cannot_be_changed_directly, on: :update

  before_validation :assign_sale_number, on: :create
  before_destroy :prevent_destroy_unless_draft

  attr_accessor :allow_status_change

  def total
    sale_items.sum(&:subtotal)
  end

  # with_lock takes a row lock (SELECT ... FOR UPDATE) on this sale and reloads
  # it before yielding, all inside its own transaction (requires_new: true, so
  # it works whether or not we're already inside one). That serializes two
  # concurrent complete!/cancel! calls for the SAME sale (double-click, retried
  # request): the second caller blocks until the first commits, then reloads
  # and sees the final status, so the idempotency check below turns it into a
  # no-op instead of double-booking stock movements / entries.
  def complete!
    with_lock do
      next if completed?

      unless draft?
        errors.add(:status, "must be draft to complete")
        raise ActiveRecord::RecordInvalid.new(self)
      end

      locked_products = lock_products_for(sale_items)

      sale_items.each do |item|
        product = locked_products.fetch(item.product_id)
        if product.stock < item.quantity
          errors.add(:base, "Insufficient stock for #{product.name}")
          raise ActiveRecord::RecordInvalid.new(self)
        end
      end

      sale_items.each do |item|
        ProductStockMovement.create!(
          product: locked_products.fetch(item.product_id),
          reason: "salida",
          quantity_delta: -item.quantity
        )
      end

      begin
        @allow_status_change = true
        update!(status: "completed")
      ensure
        @allow_status_change = false
      end

      create_associated_entry
    end
  end

  def cancel!
    with_lock do
      next if cancelled?

      unless draft? || completed?
        errors.add(:status, "must be draft or completed to cancel")
        raise ActiveRecord::RecordInvalid.new(self)
      end

      if completed?
        locked_products = lock_products_for(sale_items)

        sale_items.each do |item|
          ProductStockMovement.create!(
            product: locked_products.fetch(item.product_id),
            reason: "entrada",
            quantity_delta: item.quantity
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

    # Locks the products involved in this sale in a fixed order (by id) so two
    # concurrent transactions touching an overlapping set of products can
    # never deadlock waiting on each other in opposite orders, and so the
    # stock read below is safe from a concurrent update on the same product
    # (e.g. two sales of the last unit, or a purchase-order cancellation
    # reverting stock at the same time).
    def lock_products_for(items)
      product_ids = items.map(&:product_id).uniq.sort
      Product.where(id: product_ids).order(:id).lock.index_by(&:id)
    end

    def create_associated_entry
      sale_category = family.categories.find_or_create_by!(name: "Ventas") do |category|
        category.color = "#10b981"
        category.lucide_icon = "shopping-cart"
      end
      transaction_entryable = Transaction.new(category: sale_category)
      entry_record = account.entries.create!(
        entryable: transaction_entryable,
        name: "Venta ##{sale_number}#{client_name.present? ? " - #{client_name}" : ""}",
        date: Date.current,
        amount: -total_in_account_currency,
        currency: account.currency
      )
      update_column(:entry_id, entry_record.id)
      entry_record.sync_account_later
    end

    # `total` is denominated in the sale's own currency (user-selected on the
    # form, independent from the account's currency). Convert it to the
    # account's currency before recording the entry so a USD sale on a PYG
    # account (or vice versa) doesn't silently post the raw number under the
    # wrong currency. Mirrors the Money#exchange_to + rescue fallback pattern
    # used for cross-currency amounts elsewhere (e.g. ReportsController).
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

    def assign_sale_number
      if sale_number.blank? && family.present?
        self.sale_number = family.sales.maximum(:sale_number).to_i + 1
      end
    end

    def status_cannot_be_changed_directly
      if status_changed? && !@allow_status_change
        errors.add(:status, "cannot be changed directly. Use complete! or cancel! instead.")
      end
    end

    def prevent_destroy_unless_draft
      unless draft?
        errors.add(:base, "Cannot delete a sale that is not in draft status. Cancel it first.")
        throw :abort
      end
    end
end
