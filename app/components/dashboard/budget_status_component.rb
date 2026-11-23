module Dashboard
  class BudgetStatusComponent < BaseWidgetComponent
    def initialize(family:, user: nil, date: Date.current)
      super(family: family)
      @user = user
      @date = date
    end

    def budget
      return @budget if defined?(@budget)

      @budget = Budget.find_or_bootstrap(family, start_date: @date, user: @user)
    end

    def budgeted_money
      @budgeted_money ||= if budget&.initialized?
        to_family_money(budget.budgeted_spending, budget.currency)
      else
        zero_money
      end
    end

    def spent_money
      @spent_money ||= if budget.present?
        to_family_money(budget.actual_spending, budget.currency)
      else
        zero_money
      end
    end

    def remaining_money
      budgeted_money - spent_money
    end

    def percentage_used
      return 0.0 if budgeted_money.amount <= 0

      ((spent_money.amount / budgeted_money.amount) * 100).round(1).to_f
    end

    def status_color
      case percentage_used
      when 0...80   then "bg-emerald-500"
      when 80...100 then "bg-amber-500"
      else               "bg-rose-600"
      end
    end

    def status_label
      return "Sin presupuesto definido" if budgeted_money.amount <= 0
      return "Presupuesto excedido"     if percentage_used >= 100
      return "Cerca del límite"         if percentage_used >= 80

      "Dentro del presupuesto"
    end
  end
end
