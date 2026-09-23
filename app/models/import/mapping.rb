class Import::Mapping < ApplicationRecord
  CREATE_NEW_KEY = "internal_new_resource"

  # Allowlist of STI subtypes and polymorphic mappable classes this hierarchy
  # is allowed to constantize into (params-driven values must never be
  # constantized without checking against these first).
  TYPES = %w[Import::CategoryMapping Import::TagMapping Import::AccountMapping Import::AccountTypeMapping].freeze
  MAPPABLE_TYPES = %w[Account Category Tag].freeze

  belongs_to :import
  belongs_to :mappable, polymorphic: true, optional: true

  validates :key, presence: true, uniqueness: { scope: [ :import_id, :type ] }, allow_blank: true

  scope :for_import, ->(import) { where(import: import) }
  scope :creational, -> { where(create_when_empty: true, mappable: nil) }
  scope :categories, -> { where(type: "Import::CategoryMapping") }
  scope :tags, -> { where(type: "Import::TagMapping") }
  scope :accounts, -> { where(type: "Import::AccountMapping") }
  scope :account_types, -> { where(type: "Import::AccountTypeMapping") }

  class << self
    def mappable_for(key)
      find_by(key: key)&.mappable
    end

    def mappables_by_key(import)
      raise NotImplementedError, "Subclass must implement mappables_by_key"
    end
  end

  def selectable_values
    raise NotImplementedError, "Subclass must implement selectable_values"
  end

  def values_count
    raise NotImplementedError, "Subclass must implement values_count"
  end

  def mappable_class
    nil
  end

  def creatable?
    mappable.nil? && key.present? && create_when_empty
  end

  def create_mappable!
    raise NotImplementedError, "Subclass must implement create_mappable!"
  end
end
