# frozen_string_literal: true

require "test_helper"

class ConsentTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @user = users(:family_admin)
  end

  test "ai_processing_granted? requires active consent" do
    assert_not Consent.ai_processing_granted?(@family)

    consent = Consent.create!(
      family: @family,
      user: @user,
      kind: "ai_processing",
      granted_at: Time.current
    )

    assert Consent.ai_processing_granted?(@family)

    consent.update!(revoked_at: Time.current)
    assert_not Consent.ai_processing_granted?(@family)
  end
end
