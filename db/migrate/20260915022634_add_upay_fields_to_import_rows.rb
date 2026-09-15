class AddUpayFieldsToImportRows < ActiveRecord::Migration[7.2]
  def change
    add_column :import_rows, :gross_amount, :string
    add_column :import_rows, :commission_amount, :string
    add_column :import_rows, :receipt_number, :string
    add_column :import_rows, :auth_code, :string
    add_column :import_rows, :card_brand, :string
    add_column :import_rows, :card_type, :string
  end
end
