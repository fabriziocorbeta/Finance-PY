require "test_helper"
require_relative "row_level_security_test"

# Regression test for a real production incident (2026-10-02): posting any
# chat message never got a response. `messages` got FORCE ROW LEVEL SECURITY
# on 2026-09-28 (20260928170000), but AssistantResponseJob.perform_later is
# called with UserMessage/AssistantMessage *objects*, which ActiveJob
# serializes as GlobalIDs and re-resolves in #deserialize_arguments_if_needed
# -- a step that runs in #perform_now BEFORE ActiveJobRowLevelSecurity's
# around_perform sets any RLS context. Under real FORCE RLS and Sidekiq's own
# (non-superuser) DB role, that lookup finds nothing, raises
# ActiveJob::DeserializationError, and ApplicationJob's `discard_on` swallows
# it silently -- so the job just vanishes and the user waits forever.
class RowLevelSecurityAssistantJobTest < ActiveSupport::TestCase
  test "messages has FORCE ROW LEVEL SECURITY set" do
    forced = ActiveRecord::Base.connection.select_value(<<~SQL)
      SELECT relforcerowsecurity FROM pg_class WHERE relname = 'messages'
    SQL
    assert_equal true, forced, "Expected messages to have FORCE ROW LEVEL SECURITY set"
  end

  test "AssistantResponseJob deserializes its UserMessage/AssistantMessage GlobalID args under real FORCE RLS" do
    chat = chats(:one)
    user_message = chat.messages.create!(type: "UserMessage", content: "hola", ai_model: "gpt-4.1")
    assistant_message = chat.messages.create!(type: "AssistantMessage", content: "", ai_model: "gpt-4.1", status: :pending)

    RowLevelSecurityTest.ensure_non_superuser_role
    ActiveRecord::Base.connection.execute("SET ROLE app_user")

    job = AssistantResponseJob.new(user_message, assistant_message)
    serialized = job.serialize
    deserialized_job = ActiveJob::Base.deserialize(serialized)

    assert_nothing_raised do
      deserialized_job.send(:deserialize_arguments_if_needed)
    end
  ensure
    ActiveRecord::Base.connection.execute("RESET ROLE") rescue nil
  end
end
