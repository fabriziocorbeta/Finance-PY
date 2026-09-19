class ImpersonationSession < ApplicationRecord
  belongs_to :impersonator, class_name: "User"
  belongs_to :impersonated, class_name: "User"

  has_many :logs, class_name: "ImpersonationSessionLog"

  enum :status, { pending: "pending", in_progress: "in_progress", complete: "complete", rejected: "rejected" }

  # A request nobody approved within this window can no longer be approved, and an
  # approved session ends by itself: support access must never be open-ended.
  REQUEST_TTL = 15.minutes
  SESSION_TTL = 1.hour

  scope :awaiting_approval, -> { pending.where("impersonation_sessions.created_at > ?", REQUEST_TTL.ago) }
  scope :active, -> { in_progress.where("COALESCE(impersonation_sessions.approved_at, impersonation_sessions.created_at) > ?", SESSION_TTL.ago) }
  scope :initiated, -> { where(id: awaiting_approval.select(:id)).or(where(id: active.select(:id))) }

  validate :impersonator_is_super_admin
  validate :impersonated_is_not_super_admin
  validate :impersonator_different_from_impersonated

  def approve!
    return true if active? # already approved: idempotent, never extends the window
    return false unless request_open?

    update! status: :in_progress, approved_at: Time.current
  end

  def request_open?
    pending? && created_at > REQUEST_TTL.ago
  end

  def active?
    in_progress? && (approved_at || created_at) > SESSION_TTL.ago
  end

  def expired?
    (pending? && !request_open?) || (in_progress? && !active?)
  end

  def reject!
    update! status: :rejected
  end

  def complete!
    update! status: :complete
  end

  private
    def impersonator_is_super_admin
      errors.add(:impersonator, "must be a super admin to impersonate") unless impersonator.super_admin?
    end

    def impersonated_is_not_super_admin
      errors.add(:impersonated, "cannot be a super admin") if impersonated.super_admin?
    end

    def impersonator_different_from_impersonated
      errors.add(:impersonator, "cannot be the same as the impersonated user") if impersonator == impersonated
    end
end
