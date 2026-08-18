class ReceivablesController < ApplicationController
  include AccountableResource

  permitted_accountable_attributes(
    :id, :total_amount, :installment_count, :due_day
  )

  def index
    # .visible es el scope ya usado por BalanceSheet::NetWorthSeriesBuilder para
    # excluir cuentas ocultas/archivadas del calculo de patrimonio -- mismo criterio aca.
    accounts = Current.family.accounts.visible.where(accountable_type: "Receivable")
    @active = accounts.reject { |a| a.balance.zero? }
    @completed = accounts.select { |a| a.balance.zero? }
  end
end
