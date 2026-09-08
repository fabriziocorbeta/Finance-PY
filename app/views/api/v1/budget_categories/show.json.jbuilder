# frozen_string_literal: true

json.data do
  json.partial! "api/v1/budget_categories/budget_category", budget_category: @budget_category
end
