class AddFirstDueDateToReceivables < ActiveRecord::Migration[7.2]
  def change
    add_column :receivables, :first_due_date, :date
  end
end
