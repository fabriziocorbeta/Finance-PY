class AddFirstDueDateToReceivables < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_column :receivables, :first_due_date, :date
  end
end
