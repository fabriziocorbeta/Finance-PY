class AddCategoriesLastSyncedAtToBudgets < ActiveRecord::Migration[7.2]
  def change
    add_column :budgets, :categories_last_synced_at, :datetime
  end
end
