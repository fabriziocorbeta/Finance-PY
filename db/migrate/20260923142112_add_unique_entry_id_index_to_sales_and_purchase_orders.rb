class AddUniqueEntryIdIndexToSalesAndPurchaseOrders < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    # Partial (entry_id IS NOT NULL) so many draft/cancelled rows with a NULL
    # entry_id don't collide - only "this sale/PO is the owner of this entry"
    # needs to be unique, which stops complete!/receive! from ever attaching
    # the same entry to two rows if a double-transition slipped past the
    # sale/purchase_order row lock. Verified against prod on 2026-09-23: 0
    # duplicate entry_id values in sales and purchase_orders.
    add_index :sales, :entry_id,
      unique: true, where: "entry_id IS NOT NULL",
      name: "index_sales_on_entry_id_unique", algorithm: :concurrently
    add_index :purchase_orders, :entry_id,
      unique: true, where: "entry_id IS NOT NULL",
      name: "index_purchase_orders_on_entry_id_unique", algorithm: :concurrently

    remove_index :sales, name: "index_sales_on_entry_id", algorithm: :concurrently
    remove_index :purchase_orders, name: "index_purchase_orders_on_entry_id", algorithm: :concurrently
  end

  def down
    add_index :sales, :entry_id, name: "index_sales_on_entry_id", algorithm: :concurrently
    add_index :purchase_orders, :entry_id, name: "index_purchase_orders_on_entry_id", algorithm: :concurrently

    remove_index :sales, name: "index_sales_on_entry_id_unique", algorithm: :concurrently
    remove_index :purchase_orders, name: "index_purchase_orders_on_entry_id_unique", algorithm: :concurrently
  end
end
