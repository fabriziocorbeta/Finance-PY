# frozen_string_literal: true

json.currency @account.currency
json.period @period.key

json.series @series.values do |v|
  json.date v.date.iso8601
  json.balance v.value.to_f
end

if @series.trend
  t = @series.trend
  json.trend do
    json.start_balance t.previous.to_f
    json.end_balance t.current.to_f
    json.value t.value.to_f
    json.percent t.percent.finite? ? t.percent : nil
    json.percent_formatted t.percent_formatted
    json.direction t.direction.to_s
    json.color t.color
  end
else
  json.trend nil
end
