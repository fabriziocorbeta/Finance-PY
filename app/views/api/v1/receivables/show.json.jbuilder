# frozen_string_literal: true

json.data do
  json.partial! "api/v1/receivables/receivable", receivable: @receivable
end
