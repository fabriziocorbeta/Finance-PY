class ForceRlsForBalancesAndHoldings < ActiveRecord::Migration[7.2]
  def up
    execute "ALTER TABLE balances FORCE ROW LEVEL SECURITY;"
    execute "ALTER TABLE holdings FORCE ROW LEVEL SECURITY;"
  end

  def down
    execute "ALTER TABLE balances NO FORCE ROW LEVEL SECURITY;"
    execute "ALTER TABLE holdings NO FORCE ROW LEVEL SECURITY;"
  end
end
