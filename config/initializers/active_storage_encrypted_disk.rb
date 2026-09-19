# DiskController normally streams the raw on-disk file with send_file. With the
# EncryptedDisk service that file is ciphertext, so decrypt through the service
# instead. Access control is unchanged: the URL is still a signed, expiring key.
Rails.application.config.to_prepare do
  module EncryptedDiskServing
    def show
      key = decode_verified_key
      service = key && named_disk_service(key[:service_name])

      if service.respond_to?(:encrypted?)
        send_data service.download(key[:key]),
                  type: key[:content_type] || "application/octet-stream",
                  disposition: key[:disposition] || "inline"
      else
        super
      end
    rescue ActiveStorage::FileNotFoundError, ActiveStorage::InvalidKeyError
      head :not_found
    end
  end

  ActiveStorage::DiskController.prepend(EncryptedDiskServing)
end
