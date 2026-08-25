require "test_helper"

class ReceivablesControllerTest < ActionDispatch::IntegrationTest
  include AccountableResourceInterfaceTest

  setup do
    sign_in @user = users(:family_admin)
    @account = accounts(:receivable)
  end

  test "index shows active and completed receivables separately" do
    get receivables_path
    assert_response :success
    assert_match "GYM Schatzi", response.body
    assert_match "Cena Javier", response.body
  end

  test "index does not show receivables the signed-in user has no access to" do
    # @account (accounts(:receivable), "GYM Schatzi") is owned by family_admin and
    # is NOT shared with family_member via any AccountShare fixture, so a family
    # member without a share should not see it on the index page.
    sign_in users(:family_member)

    get receivables_path
    assert_response :success
    assert_no_match "GYM Schatzi", response.body
  end

  test "index renders empty state and new receivable link when family has no receivables" do
    # Remove all receivable accounts for family
    @user.family.accounts.where(accountable_type: "Receivable").destroy_all

    get receivables_path
    assert_response :success
    assert_select "h1", text: "Receivables", count: 1
    assert_select "a[href=?]", new_receivable_path
    assert_match "You don't have any receivables yet.", response.body
  end

  test "creates with receivable details" do
    assert_difference -> { Account.count } => 1,
      -> { Receivable.count } => 1,
      -> { Valuation.count } => 1,
      -> { Entry.count } => 1 do
      post receivables_path, params: {
        account: {
          name: "New Receivable",
          balance: 100000,
          currency: "USD",
          institution_name: "",
          institution_domain: "",
          notes: "Test receivable",
          accountable_type: "Receivable",
          accountable_attributes: {
            total_amount: 100000,
            installment_count: 4,
            due_day: 10
          }
        }
      }
    end

    created_account = Account.order(:created_at).last

    assert_equal "New Receivable", created_account.name
    assert_equal 100000, created_account.balance
    assert_equal "USD", created_account.currency
    assert_equal 100000, created_account.accountable.total_amount.to_i
    assert_equal 4, created_account.accountable.installment_count
    assert_equal 10, created_account.accountable.due_day

    assert_redirected_to created_account
    assert_equal "Receivable account created", flash[:notice]
    assert_enqueued_with(job: SyncJob)
  end

  test "updates with receivable details" do
    assert_no_difference [ "Account.count", "Receivable.count" ] do
      patch receivable_path(@account), params: {
        account: {
          name: "Updated Receivable",
          balance: 90000,
          currency: "USD",
          accountable_type: "Receivable",
          accountable_attributes: {
            id: @account.accountable_id,
            total_amount: 120000,
            installment_count: 5,
            due_day: 20
          }
        }
      }
    end

    @account.reload

    assert_equal "Updated Receivable", @account.name
    assert_equal 90000, @account.balance
    assert_equal 120000, @account.accountable.total_amount.to_i
    assert_equal 5, @account.accountable.installment_count
    assert_equal 20, @account.accountable.due_day

    assert_redirected_to @account
    assert_equal "Receivable account updated", flash[:notice]
    assert_enqueued_with(job: SyncJob)
  end
end
