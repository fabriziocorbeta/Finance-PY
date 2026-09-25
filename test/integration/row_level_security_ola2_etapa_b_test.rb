require "test_helper"
require_relative "row_level_security_test"

# RLS Ola 2 / E1 Etapa B, item (3b)/(3c): isolation tests for the policies
# added by this etapa's migrations (db/migrate/20260923143210..143250).
# Reuses RowLevelSecurityTest's `app_user` non-superuser role (created by
# its `ensure_non_superuser_role`, GRANTed ALL on every table in the schema
# -- schema-wide, so it already covers the new tables too) instead of
# re-declaring it, since running both files' `ensure_non_superuser_role`
# would just no-op the second time.
#
# Does NOT attempt every one of the ~62 tables this etapa touched -- picks
# one representative per policy *shape*, since the shapes (not the specific
# table) are what can actually be wrong:
#   - direct family_id column (binance_items)
#   - denormalized accountable child, insert-ordering sensitive (credit_cards)
#   - denormalized entryable child, insert-ordering sensitive (trades)
#   - single join to a direct-family_id parent (balances, plaid_accounts)
#   - multi-hop join (messages -> chats -> users)
#   - polymorphic join restricted to one type (addresses -> properties)
#   - polymorphic join across multiple types (data_enrichments)
#   - recursive parent_id walk-up (rule_conditions sub-conditions)
#   - the `families` root table itself
class RowLevelSecurityOla2EtapaBTest < ActionDispatch::IntegrationTest
  setup do
    RowLevelSecurityTest.ensure_non_superuser_role

    @family_a = families(:dylan_family)
    @family_b = Family.create!(name: "Etapa B Other Family", currency: "USD")
    @user_b = User.create!(family: @family_b, email: "etapa_b_other_user@example.com", password: "password123")

    @account_b = Account.create!(family: @family_b, name: "Etapa B Other Account", currency: "USD", balance: 1000, accountable: Depository.new)

    # direct
    @binance_item_b = BinanceItem.create!(family: @family_b, name: "Other Binance", api_key: "x", api_secret: "x")

    # denormalized accountable child (credit_cards)
    @credit_card_account_b = Account.create!(family: @family_b, name: "Other CC", currency: "USD", balance: 0, accountable: CreditCard.new)
    @credit_card_b = @credit_card_account_b.accountable

    # denormalized entryable child (trades)
    @investment_account_b = Account.create!(family: @family_b, name: "Other Investment", currency: "USD", balance: 0, accountable: Investment.new)
    @trade_entry_b = Entry.create!(account: @investment_account_b, amount: 100, date: Date.current, name: "Other Trade", currency: "USD",
      entryable: Trade.new(qty: 1, price: 100, currency: "USD", security: securities(:aapl)))
    @trade_b = @trade_entry_b.entryable

    # single join (balances -> accounts)
    @balance_b = @account_b.balances.create!(date: Date.current, balance: 1000, currency: "USD")

    # single join via *_item (plaid_accounts -> plaid_items)
    @plaid_item_b = PlaidItem.create!(family: @family_b, name: "Other Plaid Item", access_token: "tok", plaid_id: "etapa-b-item-#{SecureRandom.hex(4)}")
    @plaid_account_b = PlaidAccount.create!(plaid_item: @plaid_item_b, name: "Other Plaid Account", plaid_type: "depository", plaid_subtype: "checking", currency: "USD", current_balance: 0, plaid_id: "etapa-b-acc-#{SecureRandom.hex(4)}")

    # multi-hop join (messages -> chats -> users)
    @chat_b = Chat.create!(user: @user_b, title: "Other chat")
    @message_b = @chat_b.messages.create!(content: "hi", ai_model: "gpt-4.1", type: "UserMessage")

    # polymorphic restricted to one type (addresses -> properties)
    @property_account_b = Account.create!(family: @family_b, name: "Other Property", currency: "USD", balance: 0, accountable: Property.new)
    @property_b = @property_account_b.accountable
    @address_b = Address.create!(addressable: @property_b, line1: "1 Other St", locality: "Othertown", country: "US")

    # polymorphic across multiple types (data_enrichments -> Transaction)
    @tx_entry_b = Entry.create!(account: @account_b, amount: 50, date: Date.current, name: "Other tx", currency: "USD", entryable: Transaction.new)
    @data_enrichment_b = DataEnrichment.create!(enrichable: @tx_entry_b.entryable, source: "rule", attribute_name: "notes", value: "x")

    # recursive parent_id walk-up (rule_conditions)
    @rule_b = Rule.create!(family: @family_b, resource_type: "Transaction", name: "Other rule for Etapa B",
      actions: [ Rule::Action.new(action_type: "exclude_transaction") ])
    @top_condition_b = @rule_b.conditions.create!(condition_type: "compound", operator: "all")
    @sub_condition_b = @top_condition_b.sub_conditions.create!(condition_type: "transaction_name", operator: "like", value: "Other")
  end

  test "family A cannot see family B's Etapa B rows via SELECT, and can see its own" do
    ActiveRecord::Base.connection.execute("SET ROLE app_user")
    ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql([ "SET app.current_family_id = ?", @family_a.id ])
    )

    assert_nil BinanceItem.find_by(id: @binance_item_b.id)
    assert_nil CreditCard.find_by(id: @credit_card_b.id)
    assert_nil Trade.find_by(id: @trade_b.id)
    assert_nil Balance.find_by(id: @balance_b.id)
    assert_nil PlaidAccount.find_by(id: @plaid_account_b.id)
    assert_nil Message.find_by(id: @message_b.id)
    assert_nil Address.find_by(id: @address_b.id)
    assert_nil DataEnrichment.find_by(id: @data_enrichment_b.id)
    assert_nil Rule::Condition.find_by(id: @sub_condition_b.id),
      "nested sub-condition (rule_id NULL, only parent_id set) must still be hidden via the recursive walk-up policy"
    assert_nil Family.find_by(id: @family_b.id)

    # Positive: family A's own fixture-backed rows remain visible
    assert_not_nil Account.find_by(id: accounts(:depository).id)
    assert_equal @family_a, Family.find_by(id: @family_a.id)
  ensure
    ActiveRecord::Base.connection.execute("RESET app.current_family_id") rescue nil
    ActiveRecord::Base.connection.execute("RESET ROLE") rescue nil
  end

  test "family A's context still resolves family A's own Etapa B rows across every policy shape" do
    account_a = Account.create!(family: @family_a, name: "A Depository for Etapa B", currency: "USD", balance: 0, accountable: Depository.new)
    binance_item_a = BinanceItem.create!(family: @family_a, name: "A Binance", api_key: "x", api_secret: "x")
    cc_account_a = Account.create!(family: @family_a, name: "A CC", currency: "USD", balance: 0, accountable: CreditCard.new)
    balance_a = account_a.balances.create!(date: Date.current, balance: 0, currency: "USD")

    ActiveRecord::Base.connection.execute("SET ROLE app_user")
    ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql([ "SET app.current_family_id = ?", @family_a.id ])
    )

    assert_equal binance_item_a, BinanceItem.find_by(id: binance_item_a.id)
    assert_equal cc_account_a.accountable, CreditCard.find_by(id: cc_account_a.accountable.id)
    assert_equal balance_a, Balance.find_by(id: balance_a.id)
  ensure
    ActiveRecord::Base.connection.execute("RESET app.current_family_id") rescue nil
    ActiveRecord::Base.connection.execute("RESET ROLE") rescue nil
  end

  test "cross-family INSERT is rejected by WITH CHECK, not just hidden from SELECT" do
    ActiveRecord::Base.connection.execute("SET ROLE app_user")
    ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql([ "SET app.current_family_id = ?", @family_a.id ])
    )

    assert_raises(ActiveRecord::StatementInvalid) do
      # family_b here, but the connection's context is family_a -- the
      # WITH CHECK clause must reject this even though nothing stops the
      # Ruby-level .create! call from attempting it.
      BinanceItem.create!(family: @family_b, name: "Should be rejected", api_key: "x", api_secret: "x")
    end
  ensure
    ActiveRecord::Base.connection.execute("RESET app.current_family_id") rescue nil
    ActiveRecord::Base.connection.execute("RESET ROLE") rescue nil
  end

  test "inserting a credit_card/trade under RLS context succeeds despite the accountable/entryable insert-ordering constraint" do
    # Regression coverage for the same class of bug SwitchPolymorphicIndirectRlsToFamilyId
    # fixed for transactions/valuations/receivables, now that credit_cards
    # and trades also carry a denormalized family_id populated by the
    # existing generic propagate_family_id_to_accountable/entryable
    # callback (see AddFamilyIdToAccountableAndTradeTables's comment).
    ActiveRecord::Base.connection.execute("SET ROLE app_user")
    ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql([ "SET app.current_family_id = ?", @family_a.id ])
    )

    cc_account = Account.create!(family: @family_a, name: "Etapa B insert test CC", currency: "USD", balance: 0, accountable: CreditCard.new)
    assert cc_account.persisted?
    assert_equal @family_a.id, cc_account.accountable.family_id

    investment_account = Account.create!(family: @family_a, name: "Etapa B insert test Investment", currency: "USD", balance: 0, accountable: Investment.new)
    entry = investment_account.entries.new(name: "Etapa B insert test trade", date: Date.current, amount: 10, currency: "USD",
      entryable: Trade.new(qty: 1, price: 10, currency: "USD", security: securities(:aapl)))
    assert entry.save, entry.errors.full_messages.to_s
    assert_equal @family_a.id, entry.entryable.family_id
  ensure
    ActiveRecord::Base.connection.execute("RESET app.current_family_id") rescue nil
    ActiveRecord::Base.connection.execute("RESET ROLE") rescue nil
  end
end
