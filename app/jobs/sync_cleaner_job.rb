class SyncCleanerJob < ApplicationJob
  queue_as :scheduled

  def perform
    Family.find_each do |family|
      RlsContext.with_family(family) do
        Sync.clean
      end
    end
  end
end
