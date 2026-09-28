require "test_helper"
require_relative "row_level_security_test"

class RowLevelSecurityOla2EtapaDAccountablesTest < ActionDispatch::IntegrationTest
  setup do
    RowLevelSecurityTest.ensure_non_superuser_role

    @family_a = families(:dylan_family)
    @user_a = users(:family_admin)
    @member_a = users(:family_member)

    @family_b = Family.create!(name: "Etapa D Family B", currency: "USD")
    @user_b1 = User.create!(family: @family_b, email: "etapa_d_b1@example.com", password: "password123")
    @user_b2 = User.create!(family: @family_b, email: "etapa_d_b2@example.com", password: "password123")

    # Family A accounts & accountables
    @depository_account_a = Account.create!(family: @family_a, owner: @user_a, name: "A Depository", currency: "USD", balance: 1000, accountable: Depository.new(subtype: "checking"))
    @depository_a = @depository_account_a.accountable

    @credit_card_account_a = Account.create!(family: @family_a, owner: @user_a, name: "A CC", currency: "USD", balance: 500, accountable: CreditCard.new(subtype: "credit_card"))
    @credit_card_a = @credit_card_account_a.accountable

    @investment_account_a = Account.create!(family: @family_a, owner: @user_a, name: "A Investment", currency: "USD", balance: 5000, accountable: Investment.new(subtype: "brokerage"))
    @investment_a = @investment_account_a.accountable

    @crypto_account_a = Account.create!(family: @family_a, owner: @user_a, name: "A Crypto", currency: "USD", balance: 2000, accountable: Crypto.new(subtype: "crypto_wallet"))
    @crypto_a = @crypto_account_a.accountable

    @property_account_a = Account.create!(family: @family_a, owner: @user_a, name: "A Property", currency: "USD", balance: 300000, accountable: Property.new(subtype: "single_family_home"))
    @property_a = @property_account_a.accountable

    @vehicle_account_a = Account.create!(family: @family_a, owner: @user_a, name: "A Vehicle", currency: "USD", balance: 20000, accountable: Vehicle.new(subtype: "automobile", make: "Toyota", model: "Corolla", year: 2022))
    @vehicle_a = @vehicle_account_a.accountable

    @other_asset_account_a = Account.create!(family: @family_a, owner: @user_a, name: "A OtherAsset", currency: "USD", balance: 1000, accountable: OtherAsset.new(subtype: "other_asset"))
    @other_asset_a = @other_asset_account_a.accountable

    @other_liability_account_a = Account.create!(family: @family_a, owner: @user_a, name: "A OtherLiability", currency: "USD", balance: 500, accountable: OtherLiability.new(subtype: "other_liability"))
    @other_liability_a = @other_liability_account_a.accountable

    @loan_account_a = Account.create!(family: @family_a, owner: @user_a, name: "A Loan", currency: "USD", balance: 15000, accountable: Loan.new(subtype: "other"))
    @loan_a = @loan_account_a.accountable

    @trade_entry_a = Entry.create!(account: @investment_account_a, amount: 100, date: Date.current, name: "Trade A", currency: "USD",
      entryable: Trade.new(qty: 1, price: 100, currency: "USD", security: securities(:aapl)))
    @trade_a = @trade_entry_a.entryable

    @account_share_a = AccountShare.create!(account: @depository_account_a, user: @member_a, permission: "read_only")

    @plaid_item_a = PlaidItem.create!(family: @family_a, name: "Plaid A", access_token: "tok-a", plaid_id: "etapa-d-item-a-#{SecureRandom.hex(4)}")
    @plaid_account_a = PlaidAccount.create!(plaid_item: @plaid_item_a, name: "Plaid Acct A", plaid_type: "depository", plaid_subtype: "checking", currency: "USD", current_balance: 0, plaid_id: "etapa-d-acc-a-#{SecureRandom.hex(4)}")
    @account_provider_a = AccountProvider.create!(account: @depository_account_a, provider: @plaid_account_a)

    # Family B accounts & accountables
    @depository_account_b = Account.create!(family: @family_b, owner: @user_b1, name: "B Depository", currency: "USD", balance: 1000, accountable: Depository.new(subtype: "checking"))
    @depository_b = @depository_account_b.accountable

    @credit_card_account_b = Account.create!(family: @family_b, owner: @user_b1, name: "B CC", currency: "USD", balance: 500, accountable: CreditCard.new(subtype: "credit_card"))
    @credit_card_b = @credit_card_account_b.accountable

    @investment_account_b = Account.create!(family: @family_b, owner: @user_b1, name: "B Investment", currency: "USD", balance: 5000, accountable: Investment.new(subtype: "brokerage"))
    @investment_b = @investment_account_b.accountable

    @crypto_account_b = Account.create!(family: @family_b, owner: @user_b1, name: "B Crypto", currency: "USD", balance: 2000, accountable: Crypto.new(subtype: "crypto_wallet"))
    @crypto_b = @crypto_account_b.accountable

    @property_account_b = Account.create!(family: @family_b, owner: @user_b1, name: "B Property", currency: "USD", balance: 300000, accountable: Property.new(subtype: "single_family_home"))
    @property_b = @property_account_b.accountable

    @vehicle_account_b = Account.create!(family: @family_b, owner: @user_b1, name: "B Vehicle", currency: "USD", balance: 20000, accountable: Vehicle.new(subtype: "automobile", make: "Honda", model: "Civic", year: 2021))
    @vehicle_b = @vehicle_account_b.accountable

    @other_asset_account_b = Account.create!(family: @family_b, owner: @user_b1, name: "B OtherAsset", currency: "USD", balance: 1000, accountable: OtherAsset.new(subtype: "other_asset"))
    @other_asset_b = @other_asset_account_b.accountable

    @other_liability_account_b = Account.create!(family: @family_b, owner: @user_b1, name: "B OtherLiability", currency: "USD", balance: 500, accountable: OtherLiability.new(subtype: "other_liability"))
    @other_liability_b = @other_liability_account_b.accountable

    @loan_account_b = Account.create!(family: @family_b, owner: @user_b1, name: "B Loan", currency: "USD", balance: 15000, accountable: Loan.new(subtype: "other"))
    @loan_b = @loan_account_b.accountable

    @trade_entry_b = Entry.create!(account: @investment_account_b, amount: 100, date: Date.current, name: "Trade B", currency: "USD",
      entryable: Trade.new(qty: 1, price: 100, currency: "USD", security: securities(:aapl)))
    @trade_b = @trade_entry_b.entryable

    @account_share_b = AccountShare.create!(account: @depository_account_b, user: @user_b2, permission: "read_only")

    @plaid_item_b = PlaidItem.create!(family: @family_b, name: "Plaid B", access_token: "tok-b", plaid_id: "etapa-d-item-b-#{SecureRandom.hex(4)}")
    @plaid_account_b = PlaidAccount.create!(plaid_item: @plaid_item_b, name: "Plaid Acct B", plaid_type: "depository", plaid_subtype: "checking", currency: "USD", current_balance: 0, plaid_id: "etapa-d-acc-b-#{SecureRandom.hex(4)}")
    @account_provider_b = AccountProvider.create!(account: @depository_account_b, provider: @plaid_account_b)
  end

  test "family A context under forced RLS hides all 12 Family B records from SELECT" do
    ActiveRecord::Base.connection.execute("SET ROLE app_user")
    ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql([ "SET app.current_family_id = ?", @family_a.id ])
    )

    # All 12 Family B records must be invisible
    assert_nil Depository.find_by(id: @depository_b.id)
    assert_nil CreditCard.find_by(id: @credit_card_b.id)
    assert_nil Investment.find_by(id: @investment_b.id)
    assert_nil Crypto.find_by(id: @crypto_b.id)
    assert_nil Property.find_by(id: @property_b.id)
    assert_nil Vehicle.find_by(id: @vehicle_b.id)
    assert_nil OtherAsset.find_by(id: @other_asset_b.id)
    assert_nil OtherLiability.find_by(id: @other_liability_b.id)
    assert_nil Loan.find_by(id: @loan_b.id)
    assert_nil Trade.find_by(id: @trade_b.id)
    assert_nil AccountShare.find_by(id: @account_share_b.id)
    assert_nil AccountProvider.find_by(id: @account_provider_b.id)

    # Positive assertions: Family A records remain visible
    assert_equal @depository_a, Depository.find_by(id: @depository_a.id)
    assert_equal @credit_card_a, CreditCard.find_by(id: @credit_card_a.id)
    assert_equal @investment_a, Investment.find_by(id: @investment_a.id)
    assert_equal @crypto_a, Crypto.find_by(id: @crypto_a.id)
    assert_equal @property_a, Property.find_by(id: @property_a.id)
    assert_equal @vehicle_a, Vehicle.find_by(id: @vehicle_a.id)
    assert_equal @other_asset_a, OtherAsset.find_by(id: @other_asset_a.id)
    assert_equal @other_liability_a, OtherLiability.find_by(id: @other_liability_a.id)
    assert_equal @loan_a, Loan.find_by(id: @loan_a.id)
    assert_equal @trade_a, Trade.find_by(id: @trade_a.id)
    assert_equal @account_share_a, AccountShare.find_by(id: @account_share_a.id)
    assert_equal @account_provider_a, AccountProvider.find_by(id: @account_provider_a.id)

    # Raw SQL checks bypassing ActiveRecord scoping
    assert_equal 0, ActiveRecord::Base.connection.execute("SELECT 1 FROM depositories WHERE id = '#{@depository_b.id}'").count
    assert_equal 0, ActiveRecord::Base.connection.execute("SELECT 1 FROM account_shares WHERE id = '#{@account_share_b.id}'").count
    assert_equal 0, ActiveRecord::Base.connection.execute("SELECT 1 FROM account_providers WHERE id = '#{@account_provider_b.id}'").count
  ensure
    ActiveRecord::Base.connection.execute("RESET app.current_family_id") rescue nil
    ActiveRecord::Base.connection.execute("RESET ROLE") rescue nil
  end

  test "cross-family INSERT is rejected by WITH CHECK under forced RLS" do
    ActiveRecord::Base.connection.execute("SET ROLE app_user")
    ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql([ "SET app.current_family_id = ?", @family_a.id ])
    )

    # Direct family_id table: inserting row with family_b while context is family_a
    assert_raises(ActiveRecord::StatementInvalid) do
      Depository.create!(family: @family_b, subtype: "checking")
    end

    assert_raises(ActiveRecord::StatementInvalid) do
      Trade.create!(family: @family_b, security: securities(:aapl), qty: 5, price: 100, currency: "USD")
    end

    # Indirect tables: referencing Family B's account sends INSERT to Postgres
    # which rejects via WITH CHECK ((account_id IN (SELECT id FROM accounts WHERE family_id = current_family_id())))
    assert_raises(ActiveRecord::StatementInvalid) do
      share = AccountShare.new(account: @depository_account_b, user: @member_a, permission: "read_only")
      share.save!(validate: false)
    end

    assert_raises(ActiveRecord::StatementInvalid) do
      ap = AccountProvider.new(account: @depository_account_b, provider: @plaid_account_a)
      ap.save!(validate: false)
    end
  ensure
    ActiveRecord::Base.connection.execute("RESET app.current_family_id") rescue nil
    ActiveRecord::Base.connection.execute("RESET ROLE") rescue nil
  end

  test "creating accounts with each accountable type succeeds under forced RLS" do
    ActiveRecord::Base.connection.execute("SET ROLE app_user")
    ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql([ "SET app.current_family_id = ?", @family_a.id ])
    )

    [
      Depository.new(subtype: "savings"),
      CreditCard.new(subtype: "credit_card"),
      Investment.new(subtype: "brokerage"),
      Crypto.new(subtype: "crypto_wallet"),
      Property.new(subtype: "apartment"),
      Vehicle.new(subtype: "automobile", make: "Ford", model: "Focus", year: 2019),
      OtherAsset.new(subtype: "other_asset"),
      OtherLiability.new(subtype: "other_liability"),
      Loan.new(subtype: "mortgage")
    ].each do |accountable|
      acct = Account.create!(
        family: @family_a,
        owner: @user_a,
        name: "Test Account #{accountable.class.name}",
        currency: "USD",
        balance: 100,
        accountable: accountable
      )
      assert acct.persisted?, "Expected account for #{accountable.class.name} to save"
      assert acct.accountable.persisted?, "Expected #{accountable.class.name} to save"
      assert_equal @family_a.id, acct.accountable.family_id
    end
  ensure
    ActiveRecord::Base.connection.execute("RESET app.current_family_id") rescue nil
    ActiveRecord::Base.connection.execute("RESET ROLE") rescue nil
  end
end
