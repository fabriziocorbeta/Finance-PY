require "test_helper"

class Sync::TransactionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in @user = users(:family_admin)
    @account = accounts(:depository)
  end

  test "returns recent transactions for the family with a checkpoint" do
    get sync_transactions_path, as: :json

    assert_response :success
    body = JSON.parse(response.body)

    assert body.key?("documents")
    assert body.key?("checkpoint")
    assert body.key?("accounts")

    doc = body["documents"].find { |d| d["id"] == entries(:transaction).id }
    assert doc.present?, "expected entries(:transaction) in the pull response"
    assert_equal entries(:transaction).account_id, doc["account_id"]
    assert_equal "Starbucks", doc["name"]
  end

  test "excludes transactions older than the 90 day window" do
    old_entry = @account.entries.create!(
      name: "Too old",
      date: 91.days.ago.to_date,
      amount: 10,
      currency: "USD",
      entryable: Transaction.new
    )

    get sync_transactions_path, as: :json
    body = JSON.parse(response.body)

    refute body["documents"].any? { |d| d["id"] == old_entry.id }
  end

  test "excludes another family's transactions" do
    outside_account = families(:empty).accounts.create!(
      name: "Outside", balance: 0, currency: "USD", accountable: Depository.new
    )
    outside_entry = outside_account.entries.create!(
      name: "Not mine",
      date: Date.current,
      amount: 10,
      currency: "USD",
      entryable: Transaction.new
    )

    get sync_transactions_path, as: :json
    body = JSON.parse(response.body)

    refute body["documents"].any? { |d| d["id"] == outside_entry.id }
  end

  test "paginates via checkpoint" do
    get sync_transactions_path, params: { limit: 1 }, as: :json
    body = JSON.parse(response.body)

    assert_equal 1, body["documents"].size
    assert body["checkpoint"]["id"].present?
  end

  test "push creates a transaction using the client-generated id" do
    new_id = SecureRandom.uuid

    assert_difference [ "Entry.count", "Transaction.count" ], 1 do
      post push_sync_transactions_path, params: {
        rows: [ {
          id: new_id,
          account_id: @account.id,
          name: "Offline coffee",
          date: Date.current.iso8601,
          amount: "5.5",
          currency: "USD",
          notes: nil
        } ]
      }, as: :json
    end

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [ new_id ], body["applied"]
    assert_equal [], body["rejected"]

    created = Entry.find(new_id)
    assert_equal "Offline coffee", created.name
    assert_equal @account, created.account
    assert_equal 5.5, created.amount.to_f
  end

  test "push is idempotent when the same row is replayed" do
    new_id = SecureRandom.uuid
    row = {
      id: new_id, account_id: @account.id, name: "Once",
      date: Date.current.iso8601, amount: "1", currency: "USD", notes: nil
    }

    post push_sync_transactions_path, params: { rows: [ row ] }, as: :json
    assert_equal [ new_id ], JSON.parse(response.body)["applied"]

    assert_no_difference [ "Entry.count", "Transaction.count" ] do
      post push_sync_transactions_path, params: { rows: [ row ] }, as: :json
    end

    assert_response :success
    assert_equal [ new_id ], JSON.parse(response.body)["applied"]
    assert_equal [], JSON.parse(response.body)["rejected"]
  end

  test "push rejects a row targeting an inaccessible account" do
    outside_account = families(:empty).accounts.create!(
      name: "Outside", balance: 0, currency: "USD", accountable: Depository.new
    )
    new_id = SecureRandom.uuid

    assert_no_difference [ "Entry.count", "Transaction.count" ] do
      post push_sync_transactions_path, params: {
        rows: [ {
          id: new_id, account_id: outside_account.id, name: "x",
          date: Date.current.iso8601, amount: "1", currency: "USD"
        } ]
      }, as: :json
    end

    body = JSON.parse(response.body)
    assert_equal [], body["applied"]
    assert_equal 1, body["rejected"].size
    assert_equal new_id, body["rejected"].first["id"]
    assert_equal "account_not_accessible", body["rejected"].first["reason"]
  end

  test "push rejects an invalid row without aborting the valid ones" do
    good_id = SecureRandom.uuid
    bad_id = SecureRandom.uuid

    assert_difference [ "Entry.count" ], 1 do
      post push_sync_transactions_path, params: {
        rows: [
          { id: good_id, account_id: @account.id, name: "Valid", date: Date.current.iso8601, amount: "2", currency: "USD" },
          { id: bad_id, account_id: @account.id, name: "", date: Date.current.iso8601, amount: "3", currency: "USD" }
        ]
      }, as: :json
    end

    body = JSON.parse(response.body)
    assert_equal [ good_id ], body["applied"]
    assert_equal bad_id, body["rejected"].first["id"]
    assert_equal "invalid", body["rejected"].first["reason"]
  end
end
