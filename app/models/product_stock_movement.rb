class ProductStockMovement < ApplicationRecord
  belongs_to :product

  enum :reason, { entrada: "entrada", salida: "salida", ajuste: "ajuste" }

  validates :quantity_delta, presence: true, exclusion: { in: [ 0 ], message: "must be different from 0" }

  # Was after_create_commit: applying the stock delta only once the whole
  # transaction that created this movement had already committed meant the
  # product row lock taken by Sale#complete!/PurchaseOrder#receive!/cancel!
  # (see lock_products_for) was already released by the time the delta was
  # actually applied -- a second concurrent transaction for the SAME product
  # could slip in between "first transaction commits" and "its after_commit
  # callback re-acquires the lock to apply the delta", read a stale stock
  # value, and oversell. Applying it in after_create keeps it inside the
  # transaction that's already holding the lock, so the whole check-then-
  # decrement sequence is atomic. Caught by a real two-thread test
  # (test/models/sale_purchase_order_concurrency_test.rb) before this fix.
  after_create :apply_to_product_stock

  private

    def apply_to_product_stock
      product.with_lock do
        # increment! uses update_counters (raw SQL), which skips AR callbacks -
        # Product#sync_family_inventory never fires from here on its own, so
        # trigger the inventory asset sync explicitly.
        product.increment!(:stock, quantity_delta)
        product.family.sync_inventory_account!
      end
    rescue ActiveRecord::StatementInvalid => e
      # This Rails/pg-adapter combo (7.2.3.2) doesn't raise the dedicated
      # ActiveRecord::CheckConstraintViolation subclass some newer versions
      # have -- a check violation surfaces as a plain StatementInvalid wrapping
      # a PG::CheckViolation. Match on the actual PG error class so we don't
      # swallow unrelated statement errors (e.g. a lock timeout) as if they
      # were a stock problem.
      raise unless e.cause.is_a?(PG::CheckViolation)

      # Belt-and-suspenders: Sale#complete! / PurchaseOrder#cancel! already
      # lock the product and check stock before creating this movement, so
      # this should only fire for a caller that skipped that check (or a
      # future race we haven't thought of). Either way, surface it as a
      # normal validation error instead of a raw 500 from an unhandled DB
      # constraint violation.
      product.errors.add(:stock, "no puede quedar en negativo")
      raise ActiveRecord::RecordInvalid, product
    end
end
