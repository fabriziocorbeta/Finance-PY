require "test_helper"
require_relative "../integration/row_level_security_test"

class RlsMailDeliveryJobTest < ActiveJob::TestCase
  # ActiveJob resolves a mailer's GlobalID params before any RLS context is
  # set. `users` is FORCE RLS'd, so that lookup finds nothing and raises
  # DeserializationError on a user that genuinely exists -- which is what
  # happened in production: a PDF import succeeded, then its notification
  # failed and retried on a loop.
  test "delivers a mailer whose params reference a user under FORCE RLS" do
    user = users(:family_admin)
    # This mailer addresses unconfirmed_email; without it the delivery fails
    # on a blank To, which would mask what this test is actually about.
    RlsContext.with_auth_bypass(reason: "test_setup") do
      user.update!(unconfirmed_email: "nuevo@example.com")
    end

    RowLevelSecurityTest.ensure_non_superuser_role
    ActiveRecord::Base.connection.execute("SET ROLE app_user")
    ActiveRecord::Base.connection.execute("RESET app.current_family_id")

    assert_nothing_raised do
      perform_enqueued_jobs do
        EmailConfirmationMailer.with(user: user).confirmation_email.deliver_later
      end
    end
  ensure
    ActiveRecord::Base.connection.execute("RESET app.current_family_id") rescue nil
    ActiveRecord::Base.connection.execute("RESET ROLE") rescue nil
  end

  test "mailers use the RLS-aware delivery job" do
    assert_equal RlsMailDeliveryJob, ApplicationMailer.delivery_job
  end
end
