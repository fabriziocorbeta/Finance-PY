require "test_helper"

# S9 (audit 02-A3): PaperTrail stores the record's full attribute set in
# versions.object/object_changes on every change. `notes` is free-text
# user content on Account (encrypted at rest, but PaperTrail reads through
# the decrypting attribute accessor) and on Entry (searched with ILIKE, so
# it can't be column-encrypted). Both models skip :notes in their
# has_paper_trail declaration so it never lands in the versions table,
# encrypted or not.
class PaperTrailSensitiveNotesTest < ActiveSupport::TestCase
  test "changing an account's notes does not leak the plaintext into PaperTrail's versions.object_changes" do
    account = accounts(:depository)
    secret_note = "SUPER-SECRET-BALANCE-DETAIL-#{SecureRandom.hex(8)}"

    # Change :notes together with a tracked attribute so a version is
    # actually recorded (PaperTrail records nothing when every changed
    # attribute is skipped -- which is itself fine from a leak standpoint,
    # but doesn't exercise the skip: config the way a real edit would,
    # e.g. Entry#bulk_update! which sets :notes and :name together).
    account.update!(notes: secret_note, name: "Renamed for audit trail test")

    version = PaperTrail::Version.last
    assert_equal account, version.item
    assert_equal "update", version.event

    refute_includes version.object.to_s, secret_note
    refute_includes version.object_changes.to_s, secret_note

    # The rest of the audit trail still works -- non-skipped attribute
    # changes are still tracked.
    assert_includes version.object_changes.to_s, "Renamed for audit trail test"
  end

  test "raw SQL against versions confirms no plaintext note, independent of the Rails accessor" do
    account = accounts(:depository)
    secret_note = "RAW-SQL-CHECK-#{SecureRandom.hex(8)}"

    account.update!(notes: secret_note, name: "Renamed via raw SQL test")

    version_id = PaperTrail::Version.last.id
    raw_row = ActiveRecord::Base.connection.exec_query(
      "SELECT object, object_changes FROM versions WHERE id = #{version_id.to_i}"
    ).first

    refute_includes raw_row["object"].to_s, secret_note
    refute_includes raw_row["object_changes"].to_s, secret_note
  end

  test "changing an entry's notes does not leak the plaintext into PaperTrail's versions.object_changes" do
    entry = entries(:transaction)
    secret_note = "ENTRY-SECRET-NOTE-#{SecureRandom.hex(8)}"

    entry.update!(notes: secret_note, name: "Renamed entry for audit trail test")

    version = PaperTrail::Version.last
    assert_equal entry, version.item

    refute_includes version.object.to_s, secret_note
    refute_includes version.object_changes.to_s, secret_note
    assert_includes version.object_changes.to_s, "Renamed entry for audit trail test"
  end
end
