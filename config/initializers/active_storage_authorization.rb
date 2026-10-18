# Override Active Storage blob serving to enforce authorization
Rails.application.config.to_prepare do
  module ActiveStorageAttachmentAuthorization
    extend ActiveSupport::Concern

    # ArchivedExport owns the one attachment that legitimately has no family to
    # compare against: it is the export of an already-purged family, keyed by
    # email and family name rather than a family record. ArchivedExportsController
    # authorizes those downloads on its own with a single-use token digest plus an
    # expiry (ArchivedExport.find_by_download_token!), so a family check here would
    # only break a flow that is already authorized by other means.
    UNSCOPED_RECORD_TYPES = %w[ArchivedExport].freeze

    included do
      include Authentication
      before_action :authorize_attachment_access
    end

    private

      def authorize_attachment_access
        blob = authorized_blob
        return if blob.nil?

        attachment = ActiveStorage::Attachment.find_by(blob: blob)
        return if attachment.nil?
        return if UNSCOPED_RECORD_TYPES.include?(attachment.record_type)

        # Fail closed: every attachment whose owning family cannot be established
        # is refused, so a model that gains an attachment later is protected by
        # default instead of silently becoming world-readable to any signed-in user.
        owning_family = attachment.record.try(:family)

        if owning_family.nil? || Current.family != owning_family
          raise ActiveRecord::RecordNotFound
        end
      end

      def authorized_blob
        @blob || @representation&.blob
      end
  end

  [
    ActiveStorage::Blobs::RedirectController,
    ActiveStorage::Blobs::ProxyController,
    ActiveStorage::Representations::RedirectController,
    ActiveStorage::Representations::ProxyController
  ].each do |controller|
    controller.include ActiveStorageAttachmentAuthorization
  end
end
