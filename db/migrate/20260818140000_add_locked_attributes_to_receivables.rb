class AddLockedAttributesToReceivables < ActiveRecord::Migration[7.2]
  def change
    add_column :receivables, :locked_attributes, :jsonb, default: {}
  end
end
