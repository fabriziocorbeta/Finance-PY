class AllowAuthBypassForInvitationsRls < ActiveRecord::Migration[7.2]
  # invitations_family_isolation_policy (from 20260923143230) was written as
  # a generic family_id = current_family_id() check with no bypass escape
  # hatch -- correct for a table only ever read by already-authenticated
  # users, at the time it was a no-op anyway (ENABLE without FORCE, app
  # connects as the table owner). 20260928170000 later put invitations
  # under FORCE ROW LEVEL SECURITY without anyone going back to check which
  # of those 31 tables have a legitimate unauthenticated access path.
  #
  # invitations does: InvitationsController#accept/#confirm_accept look up
  # an Invitation by its public token, hit by someone who isn't a member of
  # the inviting family yet (that's the entire point of an invitation) --
  # current_family_id() is NULL for that request, so FORCE RLS has hidden
  # every invitation from the accept flow since the day it was forced. Same
  # pattern as 20260930001500 (oauth_access_grants/tokens): add the same
  # bypass clause here too.
  def up
    execute <<-SQL
      DROP POLICY IF EXISTS invitations_family_isolation_policy ON invitations;
      CREATE POLICY invitations_family_isolation_policy ON invitations
      USING (
        family_id = current_family_id()
        OR current_setting('app.rls_auth_bypass', true) = 'true'
      )
      WITH CHECK (
        family_id = current_family_id()
        OR current_setting('app.rls_auth_bypass', true) = 'true'
      );
    SQL
  end

  def down
    execute <<-SQL
      DROP POLICY IF EXISTS invitations_family_isolation_policy ON invitations;
      CREATE POLICY invitations_family_isolation_policy ON invitations
      USING (family_id = current_family_id())
      WITH CHECK (family_id = current_family_id());
    SQL
  end
end
