class InviteCode < ApplicationRecord
  include Encryptable

  # Encrypt token if ActiveRecord encryption is configured
  if encryption_ready?
    encrypts :token, deterministic: true, downcase: true
  end

  before_validation :generate_token, on: :create

  class << self
    def claim!(token)
      return false if token.blank?

      # Atomic single-use claim: only one concurrent signup can delete the row.
      where(token: token.downcase).delete_all == 1
    end

    def generate!
      create!.token
    end
  end

  private

    def generate_token
      loop do
        self.token = SecureRandom.hex(16)
        break token unless self.class.exists?(token: token)
      end
    end
end
