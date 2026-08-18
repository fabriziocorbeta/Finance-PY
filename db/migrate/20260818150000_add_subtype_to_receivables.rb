class AddSubtypeToReceivables < ActiveRecord::Migration[7.2]
  def change
    add_column :receivables, :subtype, :string
  end
end
