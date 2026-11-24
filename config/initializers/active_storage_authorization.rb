# Override Active Storage blob serving to enforce authorization
Rails.application.config.to_prepare do
  module ActiveStorageAttachmentAuthorization
    extend ActiveSupport::Concern

    included do
      include Authentication
      include RowLevelSecurity
      before_action :authorize_attachment_access
    end

    private

      def authorize_attachment_access
        blob = authorized_blob
        raise ActiveRecord::RecordNotFound if blob.nil?

        # Fail closed on orphan blobs (e.g. direct upload in flight or deleted record)
        attachment = ActiveStorage::Attachment.find_by(blob: blob)
        raise ActiveRecord::RecordNotFound if attachment.nil?

        # ArchivedExport blobs are served ONLY through ArchivedExportsController#show
        # via send_blob_stream after single-use token verification, never via
        # generic ActiveStorage blob controllers.
        raise ActiveRecord::RecordNotFound if attachment.record_type == "ArchivedExport"

        record = attachment.record
        raise ActiveRecord::RecordNotFound if record.nil?

        owning_family = resolve_owning_family(record)
        if owning_family.nil? || Current.family != owning_family
          raise ActiveRecord::RecordNotFound
        end

        enforce_intra_family_authorization!(record)
      end

      def resolve_owning_family(record)
        return record.family if record.respond_to?(:family)
        return record.chat&.user&.family if record.respond_to?(:chat)

        nil
      end

      def enforce_intra_family_authorization!(record)
        case record
        when FamilyExport
          raise ActiveRecord::RecordNotFound unless Current.user&.admin?
        when UserMessage
          raise ActiveRecord::RecordNotFound unless record.chat&.user_id == Current.user&.id
        when Transaction
          account_id = record.entry&.account_id
          raise ActiveRecord::RecordNotFound unless account_id && Account.accessible_by(Current.user).exists?(id: account_id)
        when Sale, PurchaseOrder
          raise ActiveRecord::RecordNotFound unless record.account_id && Account.accessible_by(Current.user).exists?(id: record.account_id)
        when Account
          raise ActiveRecord::RecordNotFound unless Account.accessible_by(Current.user).exists?(id: record.id)
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
