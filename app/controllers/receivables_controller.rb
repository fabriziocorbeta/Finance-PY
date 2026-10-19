class ReceivablesController < ApplicationController
  include AccountableResource

  permitted_accountable_attributes(
    :id, :total_amount, :installment_count, :due_day, :first_due_date
  )

  def index
    # .visible es el scope ya usado por BalanceSheet::NetWorthSeriesBuilder para
    # excluir cuentas ocultas/archivadas del calculo de patrimonio -- mismo criterio aca.
    # .accessible_by scopes to accounts the signed-in user owns or has an AccountShare
    # for, matching the pattern used by TransactionsController and friends.
    accounts = Current.family.accounts.visible.accessible_by(Current.user)
                       .where(accountable_type: "Receivable")
                       .includes(:accountable)
    @active = accounts.reject { |a| a.balance.zero? }
    @completed = accounts.select { |a| a.balance.zero? }
  end

  # A receivable's total_amount is the amount originally owed, so it has to
  # move the account's *opening* anchor -- not its current balance, which is
  # what's still outstanding and is derived from the payment entries. Without
  # this, editing the total left the opening balance at the old figure and the
  # paid/pending split on the dashboard stayed wrong. Everything else goes
  # through AccountableResource#update unchanged.
  def update
    total_amount = account_params.dig(:accountable_attributes, :total_amount)

    if total_amount.present?
      result = Account::OpeningBalanceManager.new(@account).set_opening_balance(balance: total_amount.to_d)
      unless result.success?
        @error_message = result.error
        render :edit, status: :unprocessable_entity
        return
      end
      @account.sync_later if result.changes_made?
    end

    super
  end
end
