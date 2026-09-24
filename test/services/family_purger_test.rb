# frozen_string_literal: true

require "test_helper"

class FamilyPurgerTest < ActiveSupport::TestCase
  test "completely purges a family, its associations and creates an anonymous deletion record" do
    family = families(:dylan_family)
    family_id = family.id
    family_hash = Digest::SHA256.hexdigest(family_id.to_s)

    # Execute purge
    counts = FamilyPurger.purge!(family)

    assert_not Family.exists?(family_id)

    # Verify anonymous audit record was created
    record = DeletionRecord.find_by(family_id_hash: family_hash)
    assert_not_nil record
    assert record.deleted_at.present?
    assert record.table_counts.is_a?(Hash)

    # Verify no records remain across tables with family_id
    ActiveRecord::Base.connection.tables.each do |table|
      next if table == "deletion_records"
      cols = ActiveRecord::Base.connection.columns(table).map(&:name)
      if cols.include?("family_id")
        remaining = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{table} WHERE family_id = '#{family_id}'").to_i
        assert_equal 0, remaining, "Expected table #{table} to have 0 records for purged family, but found #{remaining}"
      end
    end
  end
end
