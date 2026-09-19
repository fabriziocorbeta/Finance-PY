require "test_helper"

class ImpersonationMailerTest < ActionMailer::TestCase
  test "requested tells the customer nothing happens until they approve" do
    session = ImpersonationSession.create!(
      impersonator: users(:sure_support_staff), impersonated: users(:family_member), status: "pending"
    )

    mail = ImpersonationMailer.with(impersonation_session: session).requested

    assert_equal [ users(:family_member).email ], mail.to
    assert_match "Nothing happens unless you approve", mail.text_part.body.to_s
    assert_no_match %r{https?://}, mail.text_part.body.to_s # never a link that grants access
  end
end
