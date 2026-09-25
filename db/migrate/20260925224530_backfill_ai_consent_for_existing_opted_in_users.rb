# frozen_string_literal: true

# E6 (seguridad de la IA) shipped the Consent model and consents table
# but nothing ever called Consent.ai_processing_granted? -- ai_enabled?
# now requires an active consent (see app/models/user.rb), so without
# this backfill every user who already opted in via the old
# "Enable AI Chats" toggle would silently lose AI access on deploy.
#
# Treats their prior explicit toggle (the form they already submitted,
# which showed the data-handling notice) as the consent act, backdated
# to when we can't know the exact original grant time -- so `now`.
class BackfillAiConsentForExistingOptedInUsers < ActiveRecord::Migration[7.2]
  def up
    User.where(ai_enabled: true).find_each do |user|
      next unless user.family

      Consent.find_or_create_by!(family: user.family, user: user, kind: "ai_processing") do |c|
        c.granted_at = Time.current
      end
    end
  end

  def down
    # No-op: do not revoke consent on rollback, that would be a
    # destructive action on user-granted state unrelated to schema.
  end
end
