class ForceRlsForVersions < ActiveRecord::Migration[7.2]
  # EnableRlsForVersions (20260918030300) turned RLS ON for `versions` but
  # never FORCEd it -- unlike every other family-scoped table (accounts,
  # fleet_vehicles, etc., see EnableRlsForFleetAndFuel), which pairs ENABLE
  # with FORCE. Without FORCE, the table owner (and any role with
  # BYPASSRLS) ignores the policy entirely, so `versions` -- which holds
  # audit history for every family mixed together -- was not actually
  # isolated for any connection that owns the table.
  def up
    execute "ALTER TABLE versions FORCE ROW LEVEL SECURITY;"
  end

  def down
    execute "ALTER TABLE versions NO FORCE ROW LEVEL SECURITY;"
  end
end
