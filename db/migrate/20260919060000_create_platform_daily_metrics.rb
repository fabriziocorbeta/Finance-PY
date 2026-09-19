# Owner-facing aggregate ONLY: total money registered per day/currency and how
# many families were active. Deliberately has no family_id/user_id, so the
# platform owner can gauge growth without any per-customer data. It is filled
# by bin/platform_metrics.sh using the database admin role (the app role is
# subject to row level security and cannot see other families' rows).
class CreatePlatformDailyMetrics < ActiveRecord::Migration[7.2]
  def change
    create_table :platform_daily_metrics, id: false do |t|
      t.date :date, null: false
      t.string :currency, null: false
      t.decimal :total_volume, precision: 24, scale: 4, null: false, default: 0
      t.integer :entries_count, null: false, default: 0
      t.integer :active_families, null: false, default: 0
      t.timestamps
    end
    add_index :platform_daily_metrics, [ :date, :currency ], unique: true
  end
end
