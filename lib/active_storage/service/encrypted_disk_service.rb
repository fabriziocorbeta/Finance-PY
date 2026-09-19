# frozen_string_literal: true

require "active_storage/service/disk_service"
require "openssl"

module ActiveStorage
  # Disk service that stores every uploaded file AES-256-GCM encrypted at rest
  # (bank statements, CSV imports, receipts...). A copied disk/volume/backup of
  # the storage directory is unreadable without the server's encryption key.
  #
  # The key is derived from the Active Record encryption primary key, so no new
  # secret has to be managed (and it is backed up/rotated together with it).
  #
  # File layout: MAGIC(8) | IV(12) | TAG(16) | CIPHERTEXT. Files without MAGIC
  # (written before this service was enabled) are served as-is, so rollout is
  # safe; `rake storage:encrypt_existing` converts them in place.
  #
  # Files must be served through the app (proxy controller), never by serving
  # the raw path -- see config.active_storage.resolve_model_to_route.
  class Service::EncryptedDiskService < Service::DiskService
    MAGIC = "FPYENC01".b.freeze
    IV_BYTES = 12
    TAG_BYTES = 16
    STREAM_CHUNK = 1.megabyte

    def upload(key, io, checksum: nil, **)
      instrument :upload, key: key, checksum: checksum do
        plain = io.read.to_s.b
        if checksum && OpenSSL::Digest::MD5.base64digest(plain) != checksum
          raise ActiveStorage::IntegrityError
        end
        write_encrypted(key, plain)
      end
    end

    def download(key, &block)
      if block_given?
        instrument :streaming_download, key: key do
          plain = read_plain(key)
          offset = 0
          while offset < plain.bytesize
            yield plain.byteslice(offset, STREAM_CHUNK)
            offset += STREAM_CHUNK
          end
        end
      else
        instrument :download, key: key do
          read_plain(key)
        end
      end
    end

    def download_chunk(key, range)
      instrument :download_chunk, key: key, range: range do
        read_plain(key).byteslice(range.begin, range.size)
      end
    end

    # Re-write a legacy plaintext file encrypted. Returns true if converted.
    def encrypt_in_place(key)
      raw = File.binread(path_for(key))
      return false if raw.start_with?(MAGIC)

      write_encrypted(key, raw)
      true
    end

    def encrypted?(key)
      File.open(path_for(key), "rb") { |f| f.read(MAGIC.bytesize) == MAGIC }
    end

    private
      def read_plain(key)
        raw = File.binread(path_for(key))
        return raw unless raw.start_with?(MAGIC) # legacy plaintext

        iv = raw.byteslice(MAGIC.bytesize, IV_BYTES)
        tag = raw.byteslice(MAGIC.bytesize + IV_BYTES, TAG_BYTES)
        data = raw.byteslice((MAGIC.bytesize + IV_BYTES + TAG_BYTES)..)
        cipher = OpenSSL::Cipher.new("aes-256-gcm").decrypt
        cipher.key = encryption_key
        cipher.iv = iv
        cipher.auth_tag = tag
        cipher.update(data) + cipher.final
      rescue Errno::ENOENT
        raise ActiveStorage::FileNotFoundError
      end

      def write_encrypted(key, plain)
        cipher = OpenSSL::Cipher.new("aes-256-gcm").encrypt
        cipher.key = encryption_key
        iv = cipher.random_iv
        data = cipher.update(plain) + cipher.final
        path = make_path_for(key)
        tmp = "#{path}.tmp"
        File.binwrite(tmp, MAGIC + iv + cipher.auth_tag + data)
        File.rename(tmp, path) # atomic: readers never see a half-written file
      end

      def encryption_key
        @encryption_key ||= begin
          # Same key material as Active Record encryption; secret_key_base only as a
          # last resort (dev/test without AR keys) so we never fall back to plaintext.
          primary = Array(Rails.application.config.active_record.encryption.primary_key).first.presence ||
                    Rails.application.secret_key_base
          raise "No key material available for EncryptedDisk storage" if primary.blank?

          ActiveSupport::KeyGenerator.new(primary.to_s).generate_key("active_storage/encrypted_disk/v1", 32)
        end
      end
  end
end
