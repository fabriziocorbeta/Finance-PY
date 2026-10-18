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

  def show
    super
  end

  def update
    # Extract total_amount to update opening balance
    total_amount_param = account_params.dig(:accountable_attributes, :total_amount)

    if total_amount_param.present?
      result = Account::OpeningBalanceManager.new(@account).set_opening_balance(balance: total_amount_param.to_d)
      unless result.success?
        @error_message = result.error
        render :edit, status: :unprocessable_entity
        return
      end
      @account.sync_later if result.changes_made?
    end

    # Update remaining account attributes.
    update_params = account_params.except(:return_to, :balance, :opening_balance_date)
    unless @account.update(update_params)
      @error_message = @account.errors.full_messages.join(", ")
      render :edit, status: :unprocessable_entity
      return
    end

    @account.lock_saved_attributes!

    flash.now[:notice] = t("accounts.update.success", type: accountable_type.name.underscore.humanize)

    # Reload items for index
    index

    render turbo_stream: [
      turbo_stream.replace("flash-notifications", partial: "shared/flash"),
      turbo_stream.update("drawer", ""), # Close the drawer
      turbo_stream.replace("receivables-dashboard", partial: "receivables/dashboard")
    ]
  end
end
