class DataCleanerJob < ApplicationJob
  queue_as :scheduled

  def perform
    clean_expired_archived_exports
    Family.find_each do |family|
      RlsContext.with_family(family) do
        clean_old_merchant_associations(family)
        clean_expired_family_exports(family)
      end
    end
  end

  private
    def clean_old_merchant_associations(family)
      # Delete FamilyMerchantAssociation records older than 30 days
      deleted_count = FamilyMerchantAssociation
        .where(family_id: family.id, unlinked_at: ...30.days.ago)
        .delete_all

      Rails.logger.info("DataCleanerJob: Deleted #{deleted_count} old merchant associations for family #{family.id}") if deleted_count > 0
    end

    def clean_expired_family_exports(family)
      deleted = family.family_exports.expired.destroy_all.count
      Rails.logger.info("DataCleanerJob: Deleted #{deleted} expired family exports for family #{family.id}") if deleted > 0
    end

    def clean_expired_archived_exports
      deleted_count = ArchivedExport.expired.destroy_all.count

      Rails.logger.info("DataCleanerJob: Deleted #{deleted_count} expired archived exports") if deleted_count > 0
    end
end
