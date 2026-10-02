class AllowAuthBypassForChatsRls < ActiveRecord::Migration[7.2]
  # chats_family_isolation_policy (from 20260923143240) checks
  # user_id IN (SELECT ... WHERE family_id = current_family_id()) with no
  # bypass escape hatch -- harmless until 20260928170000 put chats under
  # FORCE ROW LEVEL SECURITY. ActiveJobRowLevelSecurity#resolve_job_family
  # (fixed in 75ccc0a to run under RlsContext.with_auth_bypass) reads
  # message.chat to figure out which family a job belongs to -- but that
  # bypass only helps if the *policy itself* honors the bypass GUC. It
  # didn't: messages_family_isolation_policy got the OR clause in
  # 20261002140000, but chats never did, so `message.chat` kept silently
  # returning nil even inside with_auth_bypass, and AssistantResponseJob
  # kept crashing with "undefined method 'ask_assistant' for nil" -- every
  # chat message still went unanswered after both prior fixes deployed.
  # Confirmed directly against production: raw bypassed SQL against
  # `messages` found the row, the identical bypassed query against `chats`
  # did not, until this policy got the same OR clause.
  def up
    execute <<-SQL
      DROP POLICY IF EXISTS chats_family_isolation_policy ON chats;
      CREATE POLICY chats_family_isolation_policy ON chats
      USING (
        user_id IN (
          SELECT users.id FROM users WHERE users.family_id = current_family_id()
        )
        OR current_setting('app.rls_auth_bypass', true) = 'true'
      )
      WITH CHECK (
        user_id IN (
          SELECT users.id FROM users WHERE users.family_id = current_family_id()
        )
        OR current_setting('app.rls_auth_bypass', true) = 'true'
      );
    SQL
  end

  def down
    execute <<-SQL
      DROP POLICY IF EXISTS chats_family_isolation_policy ON chats;
      CREATE POLICY chats_family_isolation_policy ON chats
      USING (
        user_id IN (
          SELECT users.id FROM users WHERE users.family_id = current_family_id()
        )
      )
      WITH CHECK (
        user_id IN (
          SELECT users.id FROM users WHERE users.family_id = current_family_id()
        )
      );
    SQL
  end
end
