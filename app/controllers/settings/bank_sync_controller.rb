class Settings::BankSyncController < ApplicationController
  layout "settings"

  def show
    # All of these are US/Canada/EU bank-connection services (Sure upstream)
    # -- none supported in FinancePY's market (Paraguay/LatAm).
    @providers = []
  end
end
