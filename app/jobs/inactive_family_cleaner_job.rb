class InactiveFamilyCleanerJob < ApplicationJob
  queue_as :scheduled

  BATCH_SIZE = 500
  ARCHIVE_EXPIRY = 90.days

  def perform(dry_run: false)
    return unless Rails.application.config.app_mode.managed?

    cutoff_with_sub = Family::CLEANUP_GRACE_PERIOD.ago
    cutoff_without_sub = (Subscription::TRIAL_DAYS.days + Family::CLEANUP_GRACE_PERIOD).ago
    # Broad candidate query on `families` only (never join FORCE-RLS `subscriptions`
    # without an active family context, or paying families look like subscription=NULL).
    candidate_families = Family.where("families.created_at < ?", cutoff_with_sub).limit(BATCH_SIZE)

    processed = 0

    candidate_families.find_each do |family|
      RlsContext.with_family(family) do
        sub = family.subscription
        eligible = if sub.present?
          sub.status.in?(%w[paused trialing]) && sub.trial_ends_at.present? && sub.trial_ends_at < cutoff_with_sub
        else
          family.created_at < cutoff_without_sub
        end
        next unless eligible

        processed += 1

        if family.requires_data_archive?
          if dry_run
            Rails.logger.info("InactiveFamilyCleanerJob: Would archive data for family #{family.id}")
          else
            archive_family_data(family)
          end
        end

        if dry_run
          Rails.logger.info("InactiveFamilyCleanerJob: Would destroy family #{family.id} (created: #{family.created_at})")
        else
          Rails.logger.info("InactiveFamilyCleanerJob: Destroying family #{family.id} (created: #{family.created_at})")
          FamilyPurger.purge!(family, allow_active_subscription: false)
        end
      end
    end

    Rails.logger.info("InactiveFamilyCleanerJob: Completed cleanup of #{processed} families#{' (dry run)' if dry_run}")
  end

  private

    def archive_family_data(family)
      export_data = Family::DataExporter.new(family).generate_export
      email = family.users.order(:created_at).first&.email

      ActiveRecord::Base.transaction do
        archive = ArchivedExport.create!(
          email: email || "unknown",
          family_name: family.name,
          expires_at: ARCHIVE_EXPIRY.from_now
        )

        archive.export_file.attach(
          io: export_data,
          filename: "sure_archive_#{family.id}.zip",
          content_type: "application/zip"
        )

        raise ActiveRecord::Rollback, "File attach failed" unless archive.export_file.attached?

        # No email in the log line: it is stored on the ArchivedExport record
        # (which is what the archive is for), but logs ship to an external
        # drain in cleartext. family.id and the archive id identify the row.
        Rails.logger.info("InactiveFamilyCleanerJob: Archived data for family #{family.id} (archive: #{archive.id}, token_digest: #{archive.download_token_digest.first(8)}...)")
      end
    end
end
