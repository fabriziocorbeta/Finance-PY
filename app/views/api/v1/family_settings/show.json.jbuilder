# frozen_string_literal: true

json.id @family.id
json.name @family.name
json.currency @family.currency
json.locale @family.locale
json.date_format @family.date_format
json.country @family.country
json.timezone @family.timezone
json.month_start_day @family.month_start_day
json.moniker @family.moniker
json.default_account_sharing @family.default_account_sharing
json.business_mode_enabled @family.business_mode_enabled?
json.custom_enabled_currencies @family.custom_enabled_currencies?
json.enabled_currencies @family.enabled_currency_codes
json.created_at @family.created_at.iso8601
json.updated_at @family.updated_at.iso8601

if @current_user
  json.current_user do
    json.id @current_user.id
    json.email @current_user.email
    json.first_name @current_user.first_name
    json.last_name @current_user.last_name
    json.display_name @current_user.display_name
    json.role @current_user.role
    json.theme @current_user.theme
    json.goals @current_user.goals
    json.onboarded_at @current_user.onboarded_at&.iso8601
    json.needs_onboarding @current_user.needs_onboarding?
    json.is_invited @family.invitations.accepted.exists?(email: @current_user.email)
  end
end

json.users @family.users.order(:created_at) do |user|
  json.id user.id
  json.email user.email
  json.first_name user.first_name
  json.last_name user.last_name
  json.display_name user.display_name
  json.role user.role
end
