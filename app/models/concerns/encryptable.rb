module Encryptable
  extend ActiveSupport::Concern

  class_methods do
    # Helper to detect if ActiveRecord Encryption is configured for this app.
    # This allows encryption to be optional - if not configured, sensitive fields
    # are stored in plaintext (useful for development or legacy deployments).
    def encryption_ready?
      Rails.application.config.active_record.encryption.primary_key.present?
    end
  end
end
