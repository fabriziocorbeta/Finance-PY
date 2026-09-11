# frozen_string_literal: true

json.data @goal_pledges do |pledge|
  json.partial! "api/v1/goal_pledges/goal_pledge", pledge: pledge
end

json.meta do
  json.current_page @pagy.page
  json.next_page @pagy.next
  json.prev_page @pagy.prev
  json.total_pages @pagy.pages
  json.total_count @pagy.count
  json.per_page @per_page
end
