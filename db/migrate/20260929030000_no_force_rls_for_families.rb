class NoForceRlsForFamilies < ActiveRecord::Migration[7.2]
  # Revert accidental FORCE on `families` from PR #403 (Etapa D lote 3).
  #
  # `families` is the root table: the very first thing a request needs to
  # bootstrap app.current_family_id is the current user's family_id, and the
  # pre-existing call sites (Authentication#authenticate_user!,
  # Api::V1::BaseController) fetched it via `Current.family&.id`, which
  # delegates to the `user.family` AR association -- an actual SELECT
  # against `families`. Under FORCE, that SELECT runs before
  # app.current_family_id is set, so `id = current_family_id()` compares
  # against NULL, matches zero rows, and Current.family is nil for the rest
  # of the request. Every family-scoped query downstream then fails with
  # NoMethodError on nil (accounts, dashboard, etc) -- this took production
  # down within minutes of the #403 deploy.
  #
  # Fixed alongside this migration: both call sites now use the raw
  # `family_id` column instead of the association, so no `families` query
  # is needed to bootstrap the RLS context. `families` itself goes back to
  # ENABLE-only (no FORCE), same as every other table before Etapa D lote 3
  # touched it -- FORCEing it again needs the auth/bootstrap path redesigned
  # first (e.g. auth_bypass around the specific bootstrap query), not just a
  # blanket FORCE like the other 46 lote 3 tables.
  def up
    execute "ALTER TABLE families NO FORCE ROW LEVEL SECURITY;"
  end

  def down
    execute "ALTER TABLE families FORCE ROW LEVEL SECURITY;"
  end
end
