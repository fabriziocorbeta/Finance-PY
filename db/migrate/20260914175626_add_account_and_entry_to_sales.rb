class AddAccountAndEntryToSales < ActiveRecord::Migration[7.2]
  def up
    add_reference :sales, :account, null: true, foreign_key: true, type: :uuid
    add_reference :sales, :entry, null: true, foreign_key: true, type: :uuid

    Sale.reset_column_information
    Sale.where(account_id: nil).find_each do |sale|
      fallback_account = sale.family.accounts.active.alphabetically.first
      next unless fallback_account
      sale.update_column(:account_id, fallback_account.id)
    end

    change_column_null :sales, :account_id, false
  end

  def down
    remove_reference :sales, :entry, foreign_key: true
    remove_reference :sales, :account, foreign_key: true
  end
end
