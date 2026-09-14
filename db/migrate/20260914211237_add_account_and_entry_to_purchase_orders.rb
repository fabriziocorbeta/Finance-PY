class AddAccountAndEntryToPurchaseOrders < ActiveRecord::Migration[7.2]
  def up
    add_reference :purchase_orders, :account, null: true, foreign_key: true, type: :uuid
    add_reference :purchase_orders, :entry, null: true, foreign_key: true, type: :uuid

    PurchaseOrder.reset_column_information

    # RLS bloquea PurchaseOrder.where(...) sin contexto de family (FORCE ROW
    # LEVEL SECURITY) -- ver 20260914175626_add_account_and_entry_to_sales.rb,
    # donde este mismo backfill sin RlsContext.set_family rompió el deploy.
    # No hay filas en producción a día de hoy, pero backfill defensivo por si
    # hay data en otro ambiente.
    Family.find_each do |family|
      RlsContext.set_family(family)
      fallback_account = family.accounts.active.alphabetically.first
      next unless fallback_account
      family.purchase_orders.where(account_id: nil).update_all(account_id: fallback_account.id)
    end

    change_column_null :purchase_orders, :account_id, false
  end

  def down
    remove_reference :purchase_orders, :entry, foreign_key: true
    remove_reference :purchase_orders, :account, foreign_key: true
  end
end
