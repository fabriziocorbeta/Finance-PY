# Converts files uploaded before EncryptedDisk was enabled (plaintext on disk)
# to the encrypted format, in place. Idempotent.
#
#   bin/rails storage:encrypt_existing
namespace :storage do
  desc "Encrypt pre-existing plaintext Active Storage files (EncryptedDisk service)"
  task encrypt_existing: :environment do
    converted = skipped = missing = 0

    ActiveStorage::Blob.find_each do |blob|
      service = blob.service
      next unless service.respond_to?(:encrypt_in_place)

      if service.encrypt_in_place(blob.key)
        converted += 1
      else
        skipped += 1
      end
    rescue Errno::ENOENT
      missing += 1
    end

    puts "converted=#{converted} already_encrypted=#{skipped} missing_files=#{missing}"
  end
end
