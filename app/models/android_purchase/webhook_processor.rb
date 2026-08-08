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
      amount: -numeric_amount.abs,
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
      BigDecimal(normalized_amount_string)
    rescue ArgumentError, TypeError
      nil
    end

    # Tasker sends the amount as whatever string it scraped from the
    # notification. PYG notifications render thousands with a dot
    # ("Gs. 150.000"), which BigDecimal would otherwise silently misread
    # as a decimal (150.000 -> 150.0) -- a 1000x-smaller amount saved with
    # no error, since PYG amounts round-trip fine as a smaller-but-valid
    # number. Disambiguate the three formats we can actually see:
    #   "1.250.000,50"  -> comma-decimal, dot-thousands (es-PY/es-AR style)
    #   "150.000"       -> dot-thousands, no decimal part
    #   "12.50"         -> plain decimal (single dot, 1-2 trailing digits)
    def normalized_amount_string
      str = @amount.to_s.strip

      if str.match?(/\A-?\d{1,3}(\.\d{3})*,\d+\z/)
        str.delete(".").sub(",", ".")
      elsif str.match?(/\A-?\d{1,3}(\.\d{3})+\z/)
        str.delete(".")
      else
        str
      end
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
