# frozen_string_literal: true

money_cents = lambda do |money|
  (money.amount * money.currency.minor_unit_conversion).round(0).to_i if money
end

json.greeting_name @greeting_name
json.currency @currency
json.period do
  json.key @period.key
  json.label @period.label
end

json.net_worth do
  net_worth_money = @balance_sheet.net_worth_money
  json.amount net_worth_money.amount.to_f
  json.amount_cents money_cents.call(net_worth_money)
  json.currency @currency

  series = @net_worth_series
  json.series series.values.map { |v|
    {
      date: v.date,
      date_formatted: v.date_formatted,
      value: v.value.to_f
    }
  }

  if series.trend
    json.trend do
      t = series.trend
      json.value t.value.to_f
      json.percent t.percent.finite? ? t.percent : nil
      json.percent_formatted t.percent_formatted
      json.direction t.direction.to_s
      json.color t.color
    end
  else
    json.trend nil
  end
end

json.cashflow_sankey do
  json.currency_symbol @cashflow_sankey[:currency_symbol]
  json.nodes @cashflow_sankey[:nodes]
  json.links @cashflow_sankey[:links].map { |l| l.merge(source: l[:source], target: l[:target]) }
end

json.outflows_donut do
  json.currency @outflows_donut[:currency]
  json.currency_symbol @outflows_donut[:currency_symbol]
  json.total @outflows_donut[:total]
  json.categories @outflows_donut[:categories]
end

json.balance_sheet do
  json.classification_groups @balance_sheet.classification_groups do |cg|
    json.classification cg.classification
    json.name cg.name
    json.icon cg.icon
    json.total cg.total_money.amount.to_f
    json.total_cents money_cents.call(cg.total_money)

    json.account_groups cg.account_groups do |ag|
      json.key ag.key
      json.name ag.name
      json.color ag.color
      json.weight ag.weight.to_f
      json.total ag.total_money.amount.to_f
      json.total_cents money_cents.call(ag.total_money)

      json.accounts ag.accounts do |account|
        json.id account.id
        json.name account.name
        json.balance account.balance_money.amount.to_f
        json.balance_cents money_cents.call(account.balance_money)
        json.currency account.currency
      end
    end
  end
end

json.investment_summary do
  if @has_investment_accounts
    stmt = @investment_statement
    json.portfolio_value stmt.portfolio_value_money.amount.to_f
    json.portfolio_value_cents money_cents.call(stmt.portfolio_value_money)
    json.currency @currency

    gains_trend = stmt.unrealized_gains_trend
    if gains_trend
      json.unrealized_gains do
        json.value gains_trend.value.to_f
        json.percent_formatted gains_trend.percent_formatted
        json.color gains_trend.color
      end
    else
      json.unrealized_gains nil
    end

    json.top_holdings stmt.top_holdings(limit: 5) do |holding|
      json.ticker holding.ticker
      json.name holding.name
      json.logo_url holding.security.logo_url
      json.weight (holding.weight || 0).to_f
      json.value holding.amount_money.amount.to_f
      json.value_cents money_cents.call(holding.amount_money)
      if holding.trend
        json.return_percent_formatted holding.trend.percent_formatted
        json.return_color holding.trend.color
      else
        json.return_percent_formatted nil
        json.return_color nil
      end
    end

    totals = stmt.totals(period: @period)
    json.activity do
      json.contributions totals.contributions.amount.to_f
      json.withdrawals totals.withdrawals.amount.to_f
      json.trades_count totals.trades_count
    end
  else
    json.null!
  end
end
