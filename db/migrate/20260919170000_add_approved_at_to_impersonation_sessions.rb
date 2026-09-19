class AddApprovedAtToImpersonationSessions < ActiveRecord::Migration[7.2]
  def change
    add_column :impersonation_sessions, :approved_at, :datetime
  end
end
