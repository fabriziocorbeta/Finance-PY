# frozen_string_literal: true

# ActiveJob deserializes GlobalID arguments before any around_perform runs.
# For a mailer whose params point at a FORCE-RLS table -- users, which every
# mailer takes -- that lookup happens with no RLS context set, finds nothing,
# and raises ActiveJob::DeserializationError. The user exists; it is simply
# invisible to the query.
#
# ActionMailer::MailDeliveryJob does not inherit from ApplicationJob, so it
# never picked up ActiveJobRowLevelSecurity's fix for exactly this. Seen in
# production on PdfImportMailer#next_steps:
#
#   ActiveJob::DeserializationError (Couldn't find User with 'id'="e507...")
#
# The import itself had already succeeded -- only the notification failed, and
# then retried and failed again on a loop.
class RlsMailDeliveryJob < ActionMailer::MailDeliveryJob
  private

    def deserialize_arguments_if_needed
      RlsContext.with_auth_bypass(reason: "mail_delivery_deserialize") { super }
    end
end
