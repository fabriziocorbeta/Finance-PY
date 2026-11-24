class WatchlistItem < ApplicationRecord
  CATEGORIES = %w[index etf equity crypto fund].freeze

  belongs_to :family
  belongs_to :security

  validates :security_id, uniqueness: { scope: :family_id }
  validates :category, inclusion: { in: CATEGORIES }

  scope :ordered, -> { order(pinned: :desc, position: :asc, created_at: :asc) }
  scope :indices, -> { where(category: "index") }
  scope :assets, -> { where.not(category: "index") }

  delegate :ticker, :name, :exchange_operating_mic, :exchange_name, :display_logo_url, to: :security

  def self.infer_category(ticker:, quote_type: nil)
    return "index" if ticker.to_s.start_with?("^")

    case quote_type.to_s.downcase
    when "index"
      "index"
    when "etf"
      "etf"
    when "cryptocurrency", "crypto"
      "crypto"
    when "mutualfund", "mutual fund", "fund"
      "fund"
    else
      "equity"
    end
  end
end
