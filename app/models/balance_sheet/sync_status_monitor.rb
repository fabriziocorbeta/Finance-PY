class BalanceSheet::SyncStatusMonitor
  def initialize(family)
    @family = family
  end

  def syncing?
    syncing_account_ids.any?
  end

  def account_syncing?(account)
    syncing_account_ids.include?(account.id)
  end

  private
    attr_reader :family

    def syncing_account_ids
      Rails.cache.fetch(cache_key) do
        Account.syncing_account_ids_for(family)
      end
    end

    # We re-fetch the set of syncing IDs any time a sync that belongs to the family is started or completed.
    # This ensures we're always fetching the latest sync statuses without re-querying on every page load in idle times (no syncs happening).
    def cache_key
      [
        "balance_sheet_sync_status",
        family.id,
        family.latest_sync_activity_at
      ].join("_")
    end
end
