# frozen_string_literal: true

json.data @budget_categories do |bc|
  json.partial! "api/v1/budget_categories/budget_category", budget_category: bc
end
