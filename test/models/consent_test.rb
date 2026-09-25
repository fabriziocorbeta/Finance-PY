# frozen_string_literal: true

require "test_helper"

class ConsentTest < ActiveSupport::TestCase
  setup do
    # A fresh family/user pair, not one of the fixture families that
    # test/fixtures/consents.yml already grants ai_processing consent to.
    @family = Family.create!(name: "Consent Test Family")
    @user = User.create!(
      family: @family,
      first_name: "Consent",
      last_name: "Tester",
      email: "consent-tester@example.com",
      password: "Password1!",
      password_confirmation: "Password1!",
      role: :admin
    )
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
