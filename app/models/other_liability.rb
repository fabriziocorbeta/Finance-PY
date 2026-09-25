class OtherLiability < ApplicationRecord
  include Accountable

  # See CreditCard's belongs_to :family comment.
  belongs_to :family, optional: true

  class << self
    def color
      "#737373"
    end

    def icon
      "minus"
    end

    def classification
      "liability"
    end
  end
end
