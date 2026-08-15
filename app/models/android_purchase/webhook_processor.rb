class AndroidPurchase::WebhookProcessor
  Error = Class.new(StandardError)

  def initialize(params)
    @account_id = params[:account_id].to_s
    @amount = params[:amount]
    @merchant = params[:merchant].to_s
    @item = params[:item].to_s
    @timestamp = params[:timestamp].to_s
    @raw_text = params[:raw_text].to_s
    @expected_family_id = ENV["ANDROID_WEBHOOK_FAMILY_ID"]
  end

  def process
    raise Error, "account_id is required" if @account_id.blank?
    raise Error, "amount is required and must be numeric" if numeric_amount.nil?

    account = Account.find_by(id: @account_id)
    # Same "Unknown account_id" message for both "doesn't exist" and "wrong
    # family" so a caller with a valid token can't use this to enumerate
    # which account ids exist in other families.
    if account.nil? || (@expected_family_id.present? && account.family_id != @expected_family_id)
      raise Error, "Unknown account_id: #{@account_id}"
    end

    # Built from Entry's side (not Transaction.new(entry: Entry.new(...)))
    # so that Entry -- the record whose uniqueness validation matters for
    # idempotency -- is the object we call save! on directly. Building the
    # other way round relies on the has_one :entry association's autosave
    # to persist the nested Entry; Rails silently swallows a has_one
    # autosave validation failure unless the association explicitly sets
    # autosave: true (which Entryable's `has_one :entry` does not), so a
    # duplicate POST would silently return success with no error and no
    # second row -- confirmed live against a real account before settling
    # on this direction.
    entry = Entry.new(
      account: account,
      date: parsed_date,
      name: description,
      amount: numeric_amount.abs, # positivo = egreso (Entry#classification), toda compra Wallet es un gasto
      currency: account.currency,
      source: "google_play",
      external_id: external_id,
      entryable: Transaction.new(extra: { "raw_text" => @raw_text, "source" => "google_play", "item" => @item })
    )

    entry.save!
    :created
  rescue ActiveRecord::RecordInvalid
    raise unless entry.errors.of_kind?(:external_id, :taken)

    :duplicate
  rescue ActiveRecord::RecordNotUnique
    # Two near-simultaneous duplicate POSTs (a real Tasker retry-after-network-blip
    # scenario) can both pass the app-level uniqueness validation before either
    # commits; the second INSERT then hits the DB's unique index directly. Same
    # idempotent outcome as the ActiveRecord::RecordInvalid case above.
    :duplicate
  end

  private

    def numeric_amount
      BigDecimal(@amount.to_s.delete(","))
    rescue ArgumentError, TypeError
      nil
    end

    # Deliberately excludes account_id: the DB unique index
    # (index_entries_on_account_source_and_external_id) already scopes by
    # account_id, so the same amount/timestamp/merchant hitting two
    # different accounts (not currently possible -- one account per Tasker
    # profile) would not collide across accounts.
    def external_id
      Digest::SHA256.hexdigest("#{@amount}|#{@timestamp}|#{@merchant}")
    end

    def parsed_date
      Time.zone.parse(@timestamp)&.to_date || Date.current
    rescue ArgumentError, TypeError
      Date.current
    end

    def description
      [ @merchant, @item ].reject(&:blank?).join(" - ").presence || "Google Play"
    end
end
