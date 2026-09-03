module Entryable
  extend ActiveSupport::Concern

  TYPES = %w[Valuation Transaction Trade]

  def self.from_type(entryable_type)
    entryable_type.presence_in(TYPES).constantize
  end

  included do
    include Enrichable

    has_one :entry, as: :entryable, touch: true, dependent: :destroy

    # Covers the OTHER construction direction from Entry's own
    # propagate_family_id_to_entryable callback: importers (QifImport,
    # bank-sync processors) build Transaction.new(entry: Entry.new(account:
    # ..., ...)) instead of Entry.new(entryable: Transaction.new), so the
    # entry association -- and its account -- is already in memory here by
    # the time this validates, even though Entry's own callback never ran
    # (this record is the outer one, not the associated one, in that call).
    before_validation :assign_family_from_entry, prepend: true

    scope :with_entry, -> { joins(:entry) }

    scope :visible, -> { with_entry.merge(Entry.visible) }

    scope :in_period, ->(period) {
      with_entry.where(entries: { date: period.start_date..period.end_date })
    }

    scope :reverse_chronological, -> {
      with_entry.merge(Entry.reverse_chronological)
    }

    scope :chronological, -> {
      with_entry.merge(Entry.chronological)
    }
  end

  def assign_family_from_entry
    return unless respond_to?(:family_id=)
    self.family_id ||= entry&.account&.family_id
  end
end
