class AddStockNonNegativeCheckToProducts < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    # NOT VALID first: this only takes a brief metadata lock (no full table
    # scan), so it can't block concurrent reads/writes or the app container's
    # boot-time migration run. VALIDATE CONSTRAINT afterwards does the actual
    # scan, but with a SHARE UPDATE EXCLUSIVE lock that still allows normal
    # reads/writes to proceed. Verified against prod on 2026-09-23: 0 products
    # with negative stock, so validation is expected to succeed immediately.
    add_check_constraint :products, "stock >= 0",
      name: "chk_products_stock_non_negative", validate: false
    validate_check_constraint :products, name: "chk_products_stock_non_negative"
  end

  def down
    remove_check_constraint :products, name: "chk_products_stock_non_negative"
  end
end
