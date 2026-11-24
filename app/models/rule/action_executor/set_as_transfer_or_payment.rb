class Rule::ActionExecutor::SetAsTransferOrPayment < Rule::ActionExecutor
  def type
    "select"
  end

  def options
    family.accounts.alphabetically.pluck(:name, :id)
  end

  def execute(transaction_scope, value: nil, ignore_attribute_locks: false, rule_run: nil)
    target_account = family.accounts.find_by_id(value)
    return 0 unless target_account
    scope = transaction_scope.with_entry

    count_modified_resources(scope) do |txn|
      entry = txn.entry
      unless txn.transfer?
        transfer = build_transfer(target_account, entry)
        Transfer.transaction do
          transfer.save!

          # Use DESTINATION (inflow) account for kind, matching Transfer::Creator logic
          destination_account = transfer.inflow_transaction.entry.account
          source_account = transfer.outflow_transaction.entry.account
          outflow_kind = Transfer.kind_for_account(destination_account)
          outflow_attrs = { kind: outflow_kind }

          if transfer.outflow_transaction.category_id.blank?
            auto_category = Transfer.auto_category_for(
              kind: outflow_kind,
              source_account: source_account,
              destination_account: destination_account
            )
            outflow_attrs[:category] = auto_category if auto_category.present?
          end

          transfer.outflow_transaction.update!(outflow_attrs)
          transfer.inflow_transaction.update!(kind: "funds_movement")
        end

        transfer.sync_account_later
      end
    end
  end

  private
    def build_transfer(target_account, entry)
      missing_transaction = Transaction.new(
        entry: target_account.entries.build(
          amount: entry.amount * -1,
          currency: entry.currency,
          date: entry.date,
          name: "#{target_account.liability? ? "Payment" : "Transfer"} #{entry.amount.negative? ? "to #{target_account.name}" : "from #{entry.account.name}"}",
          user_modified: true,
        )
      )

      transfer = Transfer.find_or_initialize_by(
        inflow_transaction: entry.amount.positive? ? missing_transaction : entry.transaction,
        outflow_transaction: entry.amount.positive? ? entry.transaction : missing_transaction
      )
      transfer.status = "confirmed"
      transfer
    end
end
