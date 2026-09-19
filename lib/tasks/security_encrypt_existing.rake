# Encrypts free-text columns that were written before `encrypts` was added to
# the models (Active Record only encrypts on write; support_unencrypted_data
# keeps old plaintext rows readable). Idempotent: re-running is safe.
#
#   bin/rails security:encrypt_existing
namespace :security do
  desc "Encrypt pre-existing plaintext rows of newly encrypted columns"
  task encrypt_existing: :environment do
    unless Rails.application.config.active_record.encryption.primary_key.present?
      abort "ActiveRecord encryption keys are not configured; refusing to run."
    end

    models = [ Account, Transfer, Goal, Sale, PurchaseOrder, FleetVehicle, FuelLog,
               Message, Chat, Import, Import::Row ]
    counts = Hash.new(0)

    encrypt_pass = lambda do
      models.each do |model|
        model.unscoped.find_each do |record|
          record.encrypt
          counts[model.name] += 1
        rescue => e
          warn "#{model.name} #{record.id}: #{e.class}: #{e.message}"
        end
      end
    end

    # RLS hides other families' rows, so run once per family, plus once with no
    # family for tables that are not row-level-secured.
    Family.find_each do |family|
      RlsContext.with_family(family) { encrypt_pass.call }
    end
    RlsContext.reset
    encrypt_pass.call

    puts counts.sort.map { |k, v| "#{k}: #{v}" }
  end
end
