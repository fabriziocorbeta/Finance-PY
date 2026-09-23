class Receivable < ApplicationRecord
  include Accountable

  belongs_to :family

  validates :due_day, inclusion: { in: 1..31 }, allow_nil: true
  # 360 = 30 years of monthly installments (standard mortgage-length upper
  # bound). Prevents nonsensical or abusive values (0, negative, or absurdly
  # large) from reaching installment_schedule's per-installment loop.
  validates :installment_count, numericality: { only_integer: true, in: 1..360 }, allow_nil: true

  def original_balance
    Money.new(account.first_valuation_amount, account.currency)
  end

  def installment_schedule
    return [] unless total_amount && installment_count && installment_count > 0 && account

    start_date = account.start_date || account.created_at.to_date

    total = total_amount
    base_amount = (total / installment_count).round(2)
    remainder = total - (base_amount * installment_count)

    # Convención de signos del proyecto: amount positivo = egreso, amount
    # negativo = ingreso. Un pago cobrado hacia esta cuenta es un ingreso,
    # así que las entries vienen con amount negativo -- se usa el valor
    # absoluto para las cuentas de la cuota.
    inflow_entries = account.entries.where("amount < 0").order(date: :asc)
    payments = inflow_entries.map { |e| { amount: e.amount.abs, date: e.date } }

    schedule = []
    current_due_date = nil

    (1..installment_count).each do |i|
      amount = base_amount
      amount += remainder if i == installment_count

      if due_day
        if i == 1
          candidate = Date.new(start_date.year, start_date.month, [ due_day, Date.new(start_date.year, start_date.month, -1).day ].min)
          current_due_date = candidate < start_date ? Date.new(start_date.next_month.year, start_date.next_month.month, [ due_day, Date.new(start_date.next_month.year, start_date.next_month.month, -1).day ].min) : candidate
        else
          current_due_date = Date.new(current_due_date.next_month.year, current_due_date.next_month.month, [ due_day, Date.new(current_due_date.next_month.year, current_due_date.next_month.month, -1).day ].min)
        end
      else
        current_due_date = i == 1 ? start_date.next_month : current_due_date.next_month
      end

      paid_amount = BigDecimal(0)
      paid_at = nil

      while payments.any? && paid_amount < amount
        payment = payments.first
        remaining_to_pay = amount - paid_amount

        if payment[:amount] <= remaining_to_pay
          paid_amount += payment[:amount]
          paid_at = payment[:date]
          payments.shift
        else
          paid_amount += remaining_to_pay
          paid_at = payment[:date]
          payment[:amount] -= remaining_to_pay
        end
      end

      status = if paid_amount >= amount
        :paid
      elsif paid_amount > 0
        :partial
      elsif current_due_date < Date.current
        :overdue
      else
        :pending
      end

      schedule << {
        number: i,
        due_date: current_due_date,
        amount: amount,
        paid_amount: paid_amount,
        status: status,
        paid_at: (status == :paid) ? paid_at : nil
      }
    end

    schedule
  end

  class << self
    def color
      "#F79009"
    end

    def icon
      "hand-heart"
    end

    def classification
      "asset"
    end
  end
end
