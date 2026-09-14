class Product < ApplicationRecord
  belongs_to :family

  enum :currency, { pyg: "pyg", usd: "usd" }, default: "pyg"

  has_many :stock_movements, class_name: "ProductStockMovement", dependent: :destroy
  has_many :sale_items, dependent: :restrict_with_error
  has_many :purchase_order_items, dependent: :restrict_with_error

  validates :name, presence: true
  validates :sku, uniqueness: { scope: :family_id }, allow_nil: true
  validates :buy_price, :sell_price, :stock, :min_stock, numericality: { greater_than_or_equal_to: 0 }

  # Two separate callbacks that share a method name (after_commit :sync_family_inventory
  # here, after_destroy_commit :sync_family_inventory below) collide in Rails commit
  # callback chain - only the last-registered one's condition survives, so destroy would
  # silently swallow the create/update trigger (or vice versa). One callback, one combined
  # condition, avoids that.
  after_commit :sync_family_inventory, if: -> {
    destroyed? || saved_change_to_stock? || saved_change_to_buy_price? || saved_change_to_currency?
  }

  private

    def sync_family_inventory
      family.sync_inventory_account!
    end
end
