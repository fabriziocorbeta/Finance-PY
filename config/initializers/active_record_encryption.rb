# frozen_string_literal: true

# Allow reading pre-existing plaintext values for columns that only recently
# started being encrypted (see app/models/concerns/encryptable.rb#encryption_ready?
# fix). Without this, ActiveRecord::Encryption::Errors::Decryption is raised
# when reading any row written before encryption was actually active.
Rails.application.config.active_record.encryption.support_unencrypted_data = true

# Parse comma-separated keys for seamless rotation
parse_keys = ->(val) {
  return nil if val.blank?
  keys = val.to_s.split(",").map(&:strip).reject(&:blank?)
  keys.length > 1 ? keys : keys.first
}

primary_key = parse_keys.call(ENV["ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"])
deterministic_key = parse_keys.call(ENV["ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY"])
key_derivation_salt = parse_keys.call(ENV["ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT"])

# Production enforcement: abort boot if keys are missing
# Exemption: assets:precompile in Docker build does not require real encryption secrets
is_assets_precompile = (
  caller.any? { |c| c.include?("assets:precompile") } ||
  (File.basename($PROGRAM_NAME) == "rake" && ARGV.any? { |a| a.include?("assets:precompile") })
)

if Rails.env.production? && !is_assets_precompile
  missing = []
  missing << "ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY" if primary_key.blank?
  missing << "ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY" if deterministic_key.blank?
  missing << "ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT" if key_derivation_salt.blank?

  if missing.any?
    abort "[SECURITY ERROR] Missing required Active Record encryption environment variables in production:\n  - " +
          missing.join("\n  - ") +
          "\nRefusing to start with derived or insecure encryption keys."
  end
end

if primary_key.present? && deterministic_key.present? && key_derivation_salt.present?
  Rails.application.config.active_record.encryption.primary_key = primary_key
  Rails.application.config.active_record.encryption.deterministic_key = deterministic_key
  Rails.application.config.active_record.encryption.key_derivation_salt = key_derivation_salt
elsif Rails.application.config.app_mode.self_hosted? && !Rails.application.credentials.active_record_encryption.present?
  secret_base = Rails.application.secret_key_base

  primary_key = Digest::SHA256.hexdigest("#{secret_base}:primary_key")[0..63]
  deterministic_key = Digest::SHA256.hexdigest("#{secret_base}:deterministic_key")[0..63]
  key_derivation_salt = Digest::SHA256.hexdigest("#{secret_base}:key_derivation_salt")[0..63]

  Rails.application.config.active_record.encryption.primary_key = primary_key
  Rails.application.config.active_record.encryption.deterministic_key = deterministic_key
  Rails.application.config.active_record.encryption.key_derivation_salt = key_derivation_salt
end
