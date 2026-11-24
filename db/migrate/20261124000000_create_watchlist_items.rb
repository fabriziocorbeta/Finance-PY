class CreateWatchlistItems < ActiveRecord::Migration[7.2]
  def change
    create_table :watchlist_items, id: :uuid do |t|
      t.references :family, null: false, foreign_key: true, type: :uuid
      t.references :security, null: false, foreign_key: true, type: :uuid
      t.string :category, null: false, default: "equity"
      t.integer :position, null: false, default: 0
      t.boolean :pinned, null: false, default: false

      t.timestamps
    end

    add_index :watchlist_items, [ :family_id, :security_id ], unique: true
    add_index :watchlist_items, [ :family_id, :position ]
  end
end
