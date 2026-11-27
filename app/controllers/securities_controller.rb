class SecuritiesController < ApplicationController
  LOCAL_SEARCH_LIMIT = 30

  def index
    query = params[:q].to_s.strip
    @securities = Security.search_provider(
      query,
      country_code: params[:country_code].presence
    )

    if @securities.empty? && query.present?
      @securities = fallback_local_securities(query)
    end
  end

  private
    def fallback_local_securities(query)
      term = ActiveRecord::Base.sanitize_sql_like(query.upcase)
      Security.standard.online
              .where("UPPER(ticker) LIKE :prefix OR UPPER(name) LIKE :contains",
                     prefix: "#{term}%", contains: "%#{term}%")
              .order(:ticker)
              .limit(LOCAL_SEARCH_LIMIT)
              .to_a
    end
end
