# frozen_string_literal: true

class Consent < ApplicationRecord
  belongs_to :user
  belongs_to :family

  KINDS = %w[ai_processing analytics].freeze

  validates :kind, presence: true, inclusion: { in: KINDS }

  scope :active, -> { where.not(granted_at: nil).where(revoked_at: nil) }

  def self.ai_processing_granted?(family)
    return false unless family
    # Self-hosted / dev opt-in fallback if env var bypass set, else require explicit consent
    return true if ENV["CONSENT_AI_PROCESSING_DEFAULT_GRANTED"] == "true"

    where(family: family, kind: "ai_processing").active.exists?
  end

  def self.analytics_granted?(user_or_family)
    return false unless user_or_family
    return true if ENV["CONSENT_ANALYTICS_DEFAULT_GRANTED"] == "true"

    if user_or_family.is_a?(User)
      where(user: user_or_family, kind: "analytics").active.exists?
    else
      where(family: user_or_family, kind: "analytics").active.exists?
    end
  end
end
