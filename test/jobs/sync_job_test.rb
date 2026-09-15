require "test_helper"

class SyncJobTest < ActiveJob::TestCase
  test "sync is performed" do
    syncable = accounts(:depository)

    sync = syncable.syncs.create!(window_start_date: 2.days.ago.to_date)

    sync.expects(:perform).once

    SyncJob.perform_now(sync)
  end

  # Regression: Sync#family estaba en la sección `private` del modelo.
  # ActiveJobRowLevelSecurity#extract_family detecta la family de un job con
  # `arg.respond_to?(:family)`, que no ve métodos privados -- con el método
  # privado, esto fallaba en silencio, RLS nunca se seteaba, y `sync.perform`
  # reventaba al no poder resolver `syncable` bajo FORCE ROW LEVEL SECURITY
  # (encontrado en prod: "undefined method 'family' for nil", patrimonio
  # neto sin actualizar porque los syncs de cuenta quedaban rotos).
  test "family is a public method so ActiveJobRowLevelSecurity can detect it via respond_to?" do
    syncable = accounts(:depository)
    sync = syncable.syncs.create!(window_start_date: 2.days.ago.to_date)

    assert sync.respond_to?(:family), "Sync#family must stay public for job-level RLS context detection"
    assert_equal syncable.family, sync.family
  end

  test "sets the RLS family context before performing an account sync" do
    syncable = accounts(:depository)
    sync = syncable.syncs.create!(window_start_date: 2.days.ago.to_date)

    RlsContext.expects(:with_family).with(syncable.family).at_least_once.yields
    sync.expects(:perform).once

    SyncJob.perform_now(sync)
  end

  # Regression más profunda: hacer `family` público no alcanzaba. En el
  # momento en que ActiveJobRowLevelSecurity llama a `sync.family` para
  # decidir qué contexto setear, el contexto TODAVÍA no está seteado -- así
  # que si `family` dependiera de `syncable.family` (una query contra una
  # tabla con FORCE ROW LEVEL SECURITY, como accounts), esa misma query
  # fallaría exactamente en ese momento, huevo y gallina. `family` debe poder
  # resolverse sin tocar `syncable` en absoluto cuando family_id ya está
  # denormalizado en la fila.
  test "family resolves from the denormalized family_id without touching syncable" do
    syncable = accounts(:depository)
    sync = syncable.syncs.create!(window_start_date: 2.days.ago.to_date)
    assert sync.family_id.present?, "family_id should be denormalized on create"

    sync.expects(:syncable).never
    assert_equal syncable.family, sync.family
  end
end
