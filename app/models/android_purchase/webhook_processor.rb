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

    transaction = Transaction.new(
      extra: { "raw_text" => @raw_text, "source" => "google_play", "item" => @item },
      entry: Entry.new(
        account: account,
        date: parsed_date,
        name: description,
        amount: -@amount.to_f.abs,
        currency: account.currency,
        source: "google_play",
        external_id: external_id
      )
    )

    transaction.save!
    :created
  rescue ActiveRecord::RecordInvalid
    raise unless transaction.entry&.errors&.of_kind?(:external_id, :taken)

    :duplicate
  end

  private

    def external_id
      Digest::SHA256.hexdigest("#{@amount}|#{@timestamp}|#{@merchant}")
    end

    def parsed_date
      Time.zone.parse(@timestamp).to_date
    rescue ArgumentError, TypeError
      Date.current
    end

    def description
      [ @merchant, @item ].reject(&:blank?).join(" - ").presence || "Google Play"
    end
end
