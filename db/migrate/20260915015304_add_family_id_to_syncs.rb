class AddFamilyIdToSyncs < ActiveRecord::Migration[7.2]
  # Nullable a propósito -- ver app/models/sync.rb y app/models/concerns/syncable.rb.
  #
  # `syncs` NO tiene FORCE ROW LEVEL SECURITY (es una tabla auxiliar, no
  # family-scoped por su propio esquema), pero su `syncable` es polimórfico y
  # casi siempre apunta a una tabla que SÍ la tiene (accounts, simplefin_items,
  # etc). Eso rompía ActiveJobRowLevelSecurity: para decidir qué contexto RLS
  # setear antes de correr un SyncJob, el concern necesita conocer la family
  # del sync ANTES de correrlo -- pero resolverla vía `syncable.family` es
  # justo la query que el RLS bloquea sin contexto todavía seteado (problema
  # de huevo y gallina). Mismo patrón ya resuelto para transactions/valuations/receivables
  # en 20260902010000_add_family_id_to_polymorphic_indirect_tables.rb:
  # denormalizar family_id en la fila misma en vez de depender de un join.
  #
  # No se backfillea acá: syncable puede ser Account, Family, SimplefinItem,
  # SnaptradeItem, IndexaCapitalItem, etc, cada uno con su propia protección
  # RLS -- backfillear los históricos requeriría RlsContext por cada family
  # dueña de cada tipo. No hace falta: los syncs viejos (completed/failed) no
  # se vuelven a ejecutar, y todo sync nuevo lo puebla el before_create de
  # Sync (ver app/models/sync.rb).
  def change
    add_reference :syncs, :family, null: true, foreign_key: true, type: :uuid
  end
end
