class AndroidPurchase::WebhookProcessor
  Error = Class.new(StandardError)

  def initialize(params)
    @account_id = params[:account_id].to_s
    @amount = params[:amount]
    @merchant = params[:merchant].to_s
    @item = params[:item].to_s
    @timestamp = params[:timestamp].to_s
    @raw_text = params[:raw_text].to_s
  end

  def process
    raise Error, "account_id is required" if @account_id.blank?

    account = Account.find_by(id: @account_id)
    raise Error, "Unknown account_id: #{@account_id}" unless account

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
      amount: -@amount.to_f.abs,
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
  end

  private

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
