require "test_helper"

class InvitationMailerTest < ActionMailer::TestCase
  test "invite_email" do
    invitation = invitations(:one)

    mail = InvitationMailer.invite_email(invitation)

    assert_equal I18n.t(
      "invitation_mailer.invite_email.subject",
      inviter: invitation.inviter.display_name,
      product_name: Rails.configuration.x.product_name
    ), mail.subject
    assert_equal [ invitation.email ], mail.to
    assert_equal [ "hello@example.com" ], mail.from
    assert_match "accept", mail.body.encoded
  end

  test "invite_email escapes HTML in family and inviter names" do
    invitation = invitations(:one)
    invitation.family.update!(name: '<a href="https://evil.example">x</a>')

    mail = InvitationMailer.invite_email(invitation)
    html_body = mail.html_part ? mail.html_part.body.decoded : mail.body.decoded

    assert_includes html_body, "&lt;a href=&quot;https://evil.example&quot;&gt;x&lt;/a&gt;"
    assert_not_includes html_body, '<a href="https://evil.example"'
  end
end
