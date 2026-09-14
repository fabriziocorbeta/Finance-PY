class AddAccountAndEntryToSales < ActiveRecord::Migration[7.2]
  def up
    add_reference :sales, :account, null: true, foreign_key: true, type: :uuid
    add_reference :sales, :entry, null: true, foreign_key: true, type: :uuid

    Sale.reset_column_information

    # RLS bloquea Sale.where(...) sin contexto de family (FORCE ROW LEVEL
    # SECURITY): sin esto la query ve 0 filas y el backfill no hace nada,
    # dejando NULLs invisibles hasta que change_column_null revienta.
    Family.find_each do |family|
      RlsContext.set_family(family)
      fallback_account = family.accounts.active.alphabetically.first
      next unless fallback_account
      family.sales.where(account_id: nil).update_all(account_id: fallback_account.id)
    end

    change_column_null :sales, :account_id, false
  end

  def down
    remove_reference :sales, :entry, foreign_key: true
    remove_reference :sales, :account, foreign_key: true
  end
end
