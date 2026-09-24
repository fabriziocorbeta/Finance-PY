# frozen_string_literal: true

require "active_storage/service/disk_service"
require "openssl"

module ActiveStorage
  # Disk service that stores every uploaded file AES-256-GCM encrypted at rest
  # (bank statements, CSV imports, receipts...). A copied disk/volume/backup of
  # the storage directory is unreadable without the server's encryption key.
  #
  # Supports key rotation: reads both legacy FPYENC01 and versioned FPYENC02 files,
  # while always writing new uploads with the active key (FPYENC02 + key_id).
  #
  # File layout:
  # - Legacy: MAGIC_V1(8) | IV(12) | TAG(16) | CIPHERTEXT
  # - Versioned: MAGIC_V2(8) | KEY_ID(4) | IV(12) | TAG(16) | CIPHERTEXT
  class Service::EncryptedDiskService < Service::DiskService
    MAGIC_V1 = "FPYENC01".b.freeze
    MAGIC_V2 = "FPYENC02".b.freeze
    IV_BYTES = 12
    TAG_BYTES = 16
    KEY_ID_BYTES = 4
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

    # Re-write a legacy plaintext or V1 file with the newest active key.
    def encrypt_in_place(key)
      raw = File.binread(path_for(key))
      return false if raw.start_with?(MAGIC_V2)

      plain = read_plain(key)
      write_encrypted(key, plain)
      true
    end

    def encrypted?(key)
      File.open(path_for(key), "rb") do |f|
        header = f.read(MAGIC_V1.bytesize)
        header == MAGIC_V1 || header == MAGIC_V2
      end
    end

    private
      def read_plain(key)
        raw = File.binread(path_for(key))
        if raw.start_with?(MAGIC_V2)
          key_id = raw.byteslice(MAGIC_V2.bytesize, KEY_ID_BYTES)
          iv_start = MAGIC_V2.bytesize + KEY_ID_BYTES
          iv = raw.byteslice(iv_start, IV_BYTES)
          tag = raw.byteslice(iv_start + IV_BYTES, TAG_BYTES)
          data = raw.byteslice((iv_start + IV_BYTES + TAG_BYTES)..)

          key_material = key_for_id(key_id) || active_encryption_key
          decrypt_data(data, key_material, iv, tag)
        elsif raw.start_with?(MAGIC_V1)
          iv = raw.byteslice(MAGIC_V1.bytesize, IV_BYTES)
          tag = raw.byteslice(MAGIC_V1.bytesize + IV_BYTES, TAG_BYTES)
          data = raw.byteslice((MAGIC_V1.bytesize + IV_BYTES + TAG_BYTES)..)

          # Try active key first, then historical keys
          decrypted = nil
          all_encryption_keys.each do |k|
            begin
              decrypted = decrypt_data(data, k, iv, tag)
              break
            rescue OpenSSL::Cipher::CipherError
              next
            end
          end
          raise OpenSSL::Cipher::CipherError, "Failed to decrypt legacy FPYENC01 file with available keys" unless decrypted
          decrypted
        else
          raw # legacy plaintext
        end
      rescue Errno::ENOENT
        raise ActiveStorage::FileNotFoundError
      end

      def decrypt_data(data, key, iv, tag)
        cipher = OpenSSL::Cipher.new("aes-256-gcm").decrypt
        cipher.key = key
        cipher.iv = iv
        cipher.auth_tag = tag
        cipher.update(data) + cipher.final
      end

      def write_encrypted(key, plain)
        cipher = OpenSSL::Cipher.new("aes-256-gcm").encrypt
        cipher.key = active_encryption_key
        iv = cipher.random_iv
        data = cipher.update(plain) + cipher.final
        path = make_path_for(key)
        tmp = "#{path}.tmp"

        # Write V2 format: MAGIC_V2 + KEY_ID + IV + TAG + DATA
        File.binwrite(tmp, MAGIC_V2 + active_key_id + iv + cipher.auth_tag + data)
        File.rename(tmp, path)
      end

      def all_raw_keys
        keys = Array(Rails.application.config.active_record.encryption.primary_key).flatten.compact.map(&:to_s)
        keys = [ Rails.application.secret_key_base ] if keys.blank?
        keys
      end

      def active_encryption_key
        @active_encryption_key ||= derive_key(all_raw_keys.first)
      end

      def active_key_id
        @active_key_id ||= Digest::SHA256.digest(all_raw_keys.first)[0..3]
      end

      def key_for_id(id)
        all_raw_keys.each do |raw|
          if Digest::SHA256.digest(raw)[0..3] == id
            return derive_key(raw)
          end
        end
        nil
      end

      def all_encryption_keys
        all_raw_keys.map { |raw| derive_key(raw) }
      end

      def derive_key(raw_secret)
        raise "No key material available for EncryptedDisk storage" if raw_secret.blank?
        ActiveSupport::KeyGenerator.new(raw_secret).generate_key("active_storage/encrypted_disk/v1", 32)
      end
  end
end
