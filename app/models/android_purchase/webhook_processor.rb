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
    apply_family_rules(account.family)
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

    # Best-effort: reuses the same Rules engine the rest of the app uses for
    # merchant-name-based categorization (Settings > Rules), so a Wallet
    # capture ends up categorized exactly like any other transaction would
    # once a matching rule exists -- no separate categorization logic here.
    # Never raises: a rules bug must not turn a successful purchase capture
    # into a 500 for the Android client.
    def apply_family_rules(family)
      family.rules.where(active: true, resource_type: "transaction").find_each do |rule|
        RuleJob.perform_later(rule)
      end
    rescue => e
      Rails.logger.error("AndroidPurchase::WebhookProcessor rule application error: #{e.message}")
    end

    def numeric_amount
      BigDecimal(normalized_amount_string)
    rescue ArgumentError, TypeError
      nil
    end

    # Normalizes raw string amounts sent by Tasker/Google Wallet notifications into standard decimal string format.
    # Notifications arrive with varying number formats depending on currency and locale:
    #   - "150.000"       -> dot-thousands, PYG style (whole guaranies: 150000)
    #   - "1.250.000"     -> multi-group dot-thousands (1250000)
    #   - "112,000"       -> comma-thousands (112000)
    #   - "1,250,000"     -> multi-group comma-thousands (1250000)
    #   - "1.250.000,50"  -> LatAm format (dot thousands, comma decimal: 1250000.50)
    #   - "1,250,000.50"  -> US format (comma thousands, dot decimal: 1250000.50)
    #   - "12.50" / "12.5"-> standard decimal (12.50 / 12.5)
    #   - "12,50" / "12,5"-> comma decimal (12.50 / 12.5)
    #   - "7500" / 50000  -> integer numbers
    #
    # Disambiguation Heuristic:
    # 1. Both separators present ('.' and ','):
    #    - Whichever separator appears last is the decimal separator.
    #    - If ',' is last (e.g. "1.250.000,50"): remove all '.', replace ',' with '.'.
    #    - If '.' is last (e.g. "1,250,000.50"): remove all ','.
    # 2. Multiple occurrences of a separator:
    #    - Multiple '.' (e.g. "1.250.000") or ',' (e.g. "1,250,000") means it's a thousands separator.
    # 3. Single separator with multiple groups (split by separator):
    #    - If the last group after the separator has exactly 3 digits (and there's more than 1 group,
    #      e.g. "150.000" or "112,000"): thousands separator. Remove the separator.
    #    - If the last group has 1-2 digits (e.g. "12.50" or "12,50"): decimal separator.
    #      Keep '.' or convert ',' to '.'.
    def normalized_amount_string
      str = @amount.to_s.strip
      return str if str.empty?

      has_dot = str.include?(".")
      has_comma = str.include?(",")

      if has_dot && has_comma
        last_dot = str.rindex(".")
        last_comma = str.rindex(",")
        if last_comma > last_dot
          str.delete(".").sub(",", ".")
        else
          str.delete(",")
        end
      elsif has_dot
        if str.count(".") > 1
          str.delete(".")
        else
          groups = str.split(".")
          if groups.size > 1 && groups.last.length == 3
            str.delete(".")
          elsif groups.size > 1 && groups.last.length <= 2
            str
          else
            str
          end
        end
      elsif has_comma
        if str.count(",") > 1
          str.delete(",")
        else
          groups = str.split(",")
          if groups.size > 1 && groups.last.length == 3
            str.delete(",")
          elsif groups.size > 1 && groups.last.length <= 2
            str.sub(",", ".")
          else
            str
          end
        end
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
