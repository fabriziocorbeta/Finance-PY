require "test_helper"

# Regression test for a real production incident (2026-10-02): a routine
# Dependabot bump (redis 5.4.0 -> 6.0.0) passed CI clean because nothing in
# the suite actually instantiates ActionCable's pubsub adapter -- it only
# fails lazily, the first time something tries to broadcast (e.g. a chat
# message), with Gem::LoadError: "can't activate redis (>= 4, < 6), already
# activated redis-6.0.0". That left every chat/Turbo Stream broadcast
# throwing a 500 in production until caught by the user manually testing
# the chat feature.
#
# actioncable's own redis adapter hard-requires `redis (>= 4, < 6)`
# (app/models/provider not involved -- this is Rails' own gem dependency,
# independent of whatever redis client version the rest of the app uses
# for caching/Sidekiq). Keep Gemfile's redis pin inside that range.
class ActionCableRedisAdapterTest < ActiveSupport::TestCase
  test "the configured ActionCable pubsub adapter loads without raising" do
    assert_nothing_raised do
      ActionCable.server.pubsub
    end
  end
end
