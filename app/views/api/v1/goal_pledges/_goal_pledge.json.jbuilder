# frozen_string_literal: true

json.extract! pledge, :id, :goal_id, :account_id, :amount, :currency, :kind, :status, :expires_at
json.days_left pledge.days_left
json.account_name pledge.account&.name
