# frozen_string_literal: true

json.data do
  json.partial! "api/v1/goal_pledges/goal_pledge", pledge: @pledge
end
