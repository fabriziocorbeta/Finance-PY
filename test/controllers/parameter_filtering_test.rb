require "test_helper"

class ParameterFilteringTest < ActionDispatch::IntegrationTest
  setup do
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
