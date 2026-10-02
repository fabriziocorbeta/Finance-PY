class AllowAuthBypassForMessagesRls < ActiveRecord::Migration[7.2]
  # messages_family_isolation_policy (from 20260923143240) checks the chat's
  # user's family_id = current_family_id() with no bypass escape hatch --
  # harmless until 20260928170000 put messages under FORCE ROW LEVEL
  # SECURITY. AssistantResponseJob.perform_later(message, pending) passes
  # UserMessage/AssistantMessage *objects*, which ActiveJob serializes as
  # GlobalIDs and re-resolves via Message.find in
  # #deserialize_arguments_if_needed -- a step that runs in #perform_now
  # BEFORE ActiveJobRowLevelSecurity's around_perform sets any RLS context,
  # so current_family_id() is NULL there. Under Sidekiq's non-superuser role
  # that lookup finds nothing, raises ActiveJob::DeserializationError, and
  # ApplicationJob's `discard_on` swallows it silently -- every chat message
  # has gone unanswered since messages was forced on 2026-09-28. Same
  # bypass-clause pattern as 20261001192000 (invitations) and
  # 20260930001500 (oauth_access_grants/tokens); paired with the
  # RlsContext.with_auth_bypass wrap added to
  # ActiveJobRowLevelSecurity#deserialize_arguments_if_needed.
  def up
    execute <<-SQL
      DROP POLICY IF EXISTS messages_family_isolation_policy ON messages;
      CREATE POLICY messages_family_isolation_policy ON messages
      USING (
        chat_id IN (
          SELECT chats.id FROM chats
          WHERE chats.user_id IN (
            SELECT users.id FROM users WHERE users.family_id = current_family_id()
          )
        )
        OR current_setting('app.rls_auth_bypass', true) = 'true'
      )
      WITH CHECK (
        chat_id IN (
          SELECT chats.id FROM chats
          WHERE chats.user_id IN (
            SELECT users.id FROM users WHERE users.family_id = current_family_id()
          )
        )
        OR current_setting('app.rls_auth_bypass', true) = 'true'
      );
    SQL
  end

  def down
    execute <<-SQL
      DROP POLICY IF EXISTS messages_family_isolation_policy ON messages;
      CREATE POLICY messages_family_isolation_policy ON messages
      USING (
        chat_id IN (
          SELECT chats.id FROM chats
          WHERE chats.user_id IN (
            SELECT users.id FROM users WHERE users.family_id = current_family_id()
          )
        )
      )
      WITH CHECK (
        chat_id IN (
          SELECT chats.id FROM chats
          WHERE chats.user_id IN (
            SELECT users.id FROM users WHERE users.family_id = current_family_id()
          )
        )
      );
    SQL
  end
end
