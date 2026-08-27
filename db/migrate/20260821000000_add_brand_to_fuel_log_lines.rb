class AddBrandToFuelLogLines < ActiveRecord::Migration[7.2]
  def change
    add_column :fuel_log_lines, :brand, :string
  end
end
