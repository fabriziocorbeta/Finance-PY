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

  test "AssistantResponseJob resolves the message's real chat (not nil) when it actually runs under real FORCE RLS" do
    chat = chats(:one)
    user_message = chat.messages.create!(type: "UserMessage", content: "hola", ai_model: "gpt-4.1")
    assistant_message = chat.messages.create!(type: "AssistantMessage", content: "", ai_model: "gpt-4.1", status: :pending)

    # `chats` is also under FORCE RLS (20260928170000): resolve_job_family's
    # own `arg.chat.family` lookup happens before any RLS context is set, so
    # without the policy itself honoring the bypass GUC, that association
    # silently returns nil, no family gets resolved, and the job body's
    # `message.chat` is nil -- NoMethodError: undefined method 'ask_assistant'
    # for nil, same user-visible symptom (chat never responds) as the
    # GlobalID bug above. Go through a real ActiveJob::Base.deserialize round
    # trip (not AssistantResponseJob.new(user_message, ...)) so `chat` is
    # re-queried from the DB instead of reusing the in-memory association
    # `chat.messages.create!` already cached -- a plain `.new` call here
    # passed this test even against the real (unfixed) production policy,
    # because it never issued the query that actually hits RLS.
    Chat.any_instance.expects(:ask_assistant).once.with do |msg, assistant_message: nil|
      msg.id == user_message.id
    end

    RowLevelSecurityTest.ensure_non_superuser_role
    ActiveRecord::Base.connection.execute("SET ROLE app_user")

    job = AssistantResponseJob.new(user_message, assistant_message)
    deserialized_job = ActiveJob::Base.deserialize(job.serialize)
    deserialized_job.send(:deserialize_arguments_if_needed)
    deserialized_job.perform_now
  ensure
    ActiveRecord::Base.connection.execute("RESET ROLE") rescue nil
  end
end
