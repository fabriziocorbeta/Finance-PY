class AddCardIdentifierToAccounts < ActiveRecord::Migration[7.2]
  def change
    add_column :accounts, :card_identifier, :string
  end
end
