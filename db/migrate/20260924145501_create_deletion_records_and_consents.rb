# frozen_string_literal: true

class CreateDeletionRecordsAndConsents < ActiveRecord::Migration[7.2]
  def change
    create_table :deletion_records, id: :uuid do |t|
      t.string :family_id_hash, null: false
      t.datetime :deleted_at, null: false
      t.jsonb :table_counts, default: {}, null: false

      t.timestamps
    end
    add_index :deletion_records, :family_id_hash
    add_index :deletion_records, :deleted_at

    create_table :consents, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :family, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.string :kind, null: false # 'ai_processing', 'analytics'
      t.string :version, default: "1.0", null: false
      t.datetime :granted_at
      t.datetime :revoked_at

      t.timestamps
    end
    add_index :consents, [ :family_id, :kind ]
    add_index :consents, [ :user_id, :kind ]
  end
end
