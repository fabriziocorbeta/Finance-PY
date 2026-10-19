require "test_helper"

class ParameterFilteringTest < ActionDispatch::IntegrationTest
  setup do
    # The header-filter test below renders the full application layout, which
    # references the compiled tailwind asset. Same pattern as
    # categories_controller_test and friends -- without it a fresh checkout
    # fails with "The asset 'tailwind.css' was not found in the load path".
    ensure_tailwind_build

    sign_in @user = users(:family_admin)
    @entry = entries(:transaction)
  end

  test "amount and notes params are filtered from the Rails log instead of leaking in plaintext" do
    sensitive_amount = "918273.45"
    sensitive_notes = "confidential note about client Acme Corp"

    log_output = capture_log do
      post transactions_url, params: {
        entry: {
          account_id: @entry.account_id,
          name: "Sensitive transaction",
          date: Date.current,
          currency: "USD",
          amount: sensitive_amount,
          nature: "inflow",
          notes: sensitive_notes,
          entryable_type: @entry.entryable_type,
          entryable_attributes: {
            category_id: Category.first.id,
            merchant_id: Merchant.first.id
          }
        }
      }
    end

    assert_match(/\[FILTERED\]/, log_output)
    assert_no_match(/#{Regexp.escape(sensitive_amount)}/, log_output)
    assert_no_match(/#{Regexp.escape(sensitive_notes)}/, log_output)
  end

  # config.filter_parameters covers params Rails logs for us, but a log line
  # the app writes by hand is not filtered. The emergency super-admin override
  # is the one login path that logs an identifier of its own, and it used to
  # interpolate user.email in cleartext.
  test "super admin override login logs the user id and not the email" do
    AuthConfig.stubs(:local_login_enabled?).returns(false)
    AuthConfig.stubs(:local_admin_override_enabled?).returns(true)

    admin = users(:sure_support_staff)
    assert admin.super_admin?, "fixture must be a super admin or this code path never runs"

    log_output = capture_log do
      post sessions_url, params: { email: admin.email, password: user_password_test }
    end

    assert_match(/\[AUTH\] Super admin override login/, log_output,
      "the override path must still be reached, otherwise this test proves nothing")
    assert_match(/user_id=#{admin.id}/, log_output)
    assert_no_match(/#{Regexp.escape(admin.email)}/, log_output)
  end

  # logtail-rails logs every request as a structured event with ALL request and
  # response headers in `headers_json`. `filter_parameters` does not reach
  # headers, and the gem's `http_header_filters` has no default, so without the
  # config in filter_parameter_logging.rb the session cookie, the bearer token
  # and the API key all shipped in cleartext.
  test "credential-bearing request headers are filtered out of the structured log" do
    bearer = "super-secret-bearer-value"
    api_key = "sk-not-a-real-api-key-value"

    log_output = capture_log do
      get root_path, headers: {
        "Authorization" => "Bearer #{bearer}",
        "X-Api-Key" => api_key
      }
    end

    assert_match(/http_request_received/, log_output,
      "the structured request event must still be emitted, or this test proves nothing")
    assert_match(/\[FILTERED\]/, log_output)

    assert_no_match(/#{Regexp.escape(bearer)}/, log_output)
    assert_no_match(/#{Regexp.escape(api_key)}/, log_output)
    # setup signs in, so the request carries a real session cookie
    assert_no_match(/session_token=/, log_output)
  end

  private

    # Rails logs "Parameters: {...}" via ActionController::LogSubscriber,
    # which reads ActionController::Base.logger (not necessarily the same
    # object as Rails.logger at call time), so both need to be swapped for
    # a StringIO to actually capture that line.
    def capture_log
      io = StringIO.new
      test_logger = ActiveSupport::Logger.new(io)
      test_logger.level = Logger::DEBUG

      original_rails_logger = Rails.logger
      original_controller_logger = ActionController::Base.logger

      Rails.logger = test_logger
      ActionController::Base.logger = test_logger

      yield

      io.string
    ensure
      Rails.logger = original_rails_logger
      ActionController::Base.logger = original_controller_logger
    end
end
