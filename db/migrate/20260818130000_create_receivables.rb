class CreateReceivables < ActiveRecord::Migration[7.2]
  def change
    create_table :receivables, id: :uuid do |t|
      t.decimal :total_amount, precision: 19, scale: 4
      t.integer :installment_count
      t.integer :due_day
      t.timestamps
    end
  end
end
