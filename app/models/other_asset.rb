class OtherAsset < ApplicationRecord
  include Accountable

  # See CreditCard's belongs_to :family comment.
  belongs_to :family, optional: true

  class << self
    def color
      "#12B76A"
    end

    def icon
      "plus"
    end

    def classification
      "asset"
    end
  end
end
