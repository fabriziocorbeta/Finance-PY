# frozen_string_literal: true

class Api::V1::FamilySettingsController < Api::V1::BaseController
  before_action :ensure_read_scope

  def show
    # Deliberately not the `.family` AR association here: that delegate
    # issues a SELECT against `families` gated by RLS. This action runs
    # after setup_current_context_for_api has already set
    # app.current_family_id, so it isn't currently exploitable the way the
    # P0 bootstrap bug was -- but it's the same fragile pattern, and would
    # break again the instant `families` is FORCE'd and this action's
    # before_action order ever changes. family_id is the raw FK column
    # already available on the loaded user record: no extra risk, no extra
    # query semantics to reason about here.
    @family = Family.find(current_resource_owner.family_id)
    @current_user = current_resource_owner
  end

  private

    def ensure_read_scope
      authorize_scope!(:read)
    end
end
