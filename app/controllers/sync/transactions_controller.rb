class Sync::TransactionsController < ApplicationController
  PULL_WINDOW_DAYS = 90
  DEFAULT_LIMIT = 50
  MAX_LIMIT = 200

  def index
    entries = pull_scope.limit(resolved_limit)

    render json: {
      documents: entries.map { |entry| serialize_entry(entry) },
      checkpoint: next_checkpoint(entries.last),
      accounts: Current.user.accessible_accounts.map { |a|
        { id: a.id, name: a.name, currency: a.currency }
      }
    }
  end

  def push
    applied = []
    rejected = []

    rows_params.each do |row|
      result = apply_push_row(row)

      if result[:ok]
        applied << result[:id]
      else
        rejected << { id: result[:id], reason: result[:reason] }
      end
    end

    render json: { applied: applied, rejected: rejected }
  end

  private

    def resolved_limit
      limit = params[:limit].presence&.to_i || DEFAULT_LIMIT
      limit.clamp(1, MAX_LIMIT)
    end

    def pull_scope
      scope = Current.family.entries
        .joins(:account)
        .merge(Account.accessible_by(Current.user))
        .where(entryable_type: "Transaction")
        .where("entries.date >= ?", PULL_WINDOW_DAYS.days.ago.to_date)
        .order(updated_at: :asc, id: :asc)
        .includes(:entryable)

      updated_at = params.dig(:checkpoint, :updated_at)
      id = params.dig(:checkpoint, :id)

      return scope if updated_at.blank? || id.blank?

      scope.where(
        "(entries.updated_at, entries.id) > (?, ?)",
        Time.iso8601(updated_at), id
      )
    rescue ArgumentError
      # checkpoint con timestamp malformado -- tratar como pull inicial
      scope
    end

    def next_checkpoint(last_entry)
      if last_entry.nil?
        return { updated_at: params.dig(:checkpoint, :updated_at), id: params.dig(:checkpoint, :id) }
      end

      { updated_at: last_entry.updated_at.iso8601, id: last_entry.id }
    end

    def serialize_entry(entry)
      # entryable (no entry.transaction) para aprovechar el includes(:entryable)
      # de arriba; el scope ya filtra entryable_type == "Transaction".
      transaction = entry.entryable

      {
        id: entry.id,
        account_id: entry.account_id,
        name: entry.name,
        date: entry.date.iso8601,
        amount: entry.amount.to_s,
        currency: entry.currency,
        notes: entry.notes,
        category_id: transaction.category_id,
        merchant_id: transaction.merchant_id,
        kind: transaction.kind,
        updated_at: entry.updated_at.iso8601
      }
    end

    def rows_params
      params.permit(rows: [ :id, :account_id, :name, :date, :amount, :currency, :notes ])
            .require(:rows)
    end

    def apply_push_row(row)
      id = row[:id]

      # Replay de un push que ya se aplico -- exito idempotente, no se re-crea.
      return { ok: true, id: id } if Entry.exists?(id: id)

      account = Current.user.accessible_accounts.find_by(id: row[:account_id])
      return { ok: false, id: id, reason: "account_not_accessible" } if account.nil?

      entry = account.entries.new(
        id: id,
        name: row[:name],
        date: row[:date],
        amount: row[:amount],
        currency: row[:currency],
        notes: row[:notes],
        entryable: Transaction.new
      )

      if entry.save
        entry.sync_account_later
        { ok: true, id: id }
      else
        Rails.logger.warn("[sync push] rejected #{id}: #{entry.errors.full_messages.join(', ')}")
        { ok: false, id: id, reason: "invalid" }
      end
    end
end
