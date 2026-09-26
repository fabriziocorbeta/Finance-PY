# frozen_string_literal: true

class FamilyPurger
  def self.purge!(family)
    new(family).purge!
  end

  def initialize(family)
    @family = family
  end

  def purge!
    family_id = @family.id
    family_hash = Digest::SHA256.hexdigest(family_id.to_s)
    counts = {}
    conn = ActiveRecord::Base.connection

    RlsContext.with_family(family_id) do
      ActiveRecord::Base.transaction do
        # 1. Purge ActiveStorage blobs for this family
        if defined?(Import)
          Import.where(family_id: family_id).find_each do |imp|
            imp.pdf_file.purge if imp.respond_to?(:pdf_file) && imp.pdf_file.attached?
            imp.raw_file.purge if imp.respond_to?(:raw_file) && imp.raw_file.attached?
          end
        end

        # 2. Record table counts before deletion
        ActiveRecord::Base.connection.tables.each do |table|
          cols = ActiveRecord::Base.connection.columns(table).map(&:name)
          if cols.include?("family_id")
            cnt = conn.select_value(
              "SELECT COUNT(*) FROM #{conn.quote_table_name(table)} WHERE family_id = #{conn.quote(family_id)}"
            ).to_i
            counts[table] = cnt if cnt > 0
          end
        end

        # 3. Clean PaperTrail versions if present
        if defined?(PaperTrail::Version)
          PaperTrail::Version.where(family_id: family_id).delete_all if ActiveRecord::Base.connection.columns("versions").map(&:name).include?("family_id")
        end

        # 3b. Consent (E6) has no has_many :consents on Family, so it would
        # not cascade on family.destroy! below and would be left orphaned --
        # same reasoning as the versions cleanup above.
        Consent.where(family_id: family_id).delete_all if defined?(Consent)

        # 3c. FamilyMerchantAssociation has no has_many on Family either, and
        # unlike consents/versions its family_id FK has no ON DELETE CASCADE
        # -- so without this cleanup, family.destroy! below would not just
        # orphan rows, it would raise a foreign key violation and abort the
        # whole purge for any family that ever had a merchant association.
        FamilyMerchantAssociation.where(family_id: family_id).delete_all if defined?(FamilyMerchantAssociation)

        # 4. Destroy family record with cascading associations
        @family.destroy!
        conn.execute("DELETE FROM versions WHERE family_id = #{conn.quote(family_id)}")

        # 5. Write anonymous deletion audit record
        DeletionRecord.create!(
          family_id_hash: family_hash,
          deleted_at: Time.current,
          table_counts: counts
        )
      end
    end

    counts
  end
end
