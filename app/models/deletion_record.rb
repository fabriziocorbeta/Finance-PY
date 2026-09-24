# frozen_string_literal: true

class DeletionRecord < ApplicationRecord
  validates :family_id_hash, presence: true
  validates :deleted_at, presence: true
end
