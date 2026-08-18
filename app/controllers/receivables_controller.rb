class ReceivablesController < ApplicationController
  include AccountableResource

  permitted_accountable_attributes(
    :id, :total_amount, :installment_count, :due_day
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
end
