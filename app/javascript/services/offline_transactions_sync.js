// Sincronización de transacciones offline contra los endpoints Sync:: de Rails.
//
//   pull  -> GET  /sync/transactions        (paginado por checkpoint, ventana de 90 días)
//   push  -> POST /sync/transactions/push   (solo creates, idempotente por UUID de cliente)
//
// Sin librería de sync a propósito: este proyecto no tiene bundler (todo el JS
// va por importmap), así que la lógica de checkpoint/replay se maneja acá.

import {
  cacheDocuments,
  getCheckpoint,
  saveCheckpoint,
  saveAccounts,
  getQueuedWrites,
  deleteQueuedWrite,
} from "services/offline_transactions_db";

const PULL_BATCH_SIZE = 100;
// Tope de páginas por corrida: evita un loop infinito si el server devolviera
// siempre un checkpoint que no avanza.
const MAX_PULL_PAGES = 20;

function csrfToken() {
  const meta = document.querySelector('meta[name="csrf-token"]');
  return meta ? meta.content : null;
}

export async function pullTransactions() {
  let checkpoint = await getCheckpoint();

  for (let page = 0; page < MAX_PULL_PAGES; page++) {
    const url = new URL("/sync/transactions", window.location.origin);
    url.searchParams.set("limit", String(PULL_BATCH_SIZE));

    if (checkpoint?.updated_at && checkpoint.id) {
      url.searchParams.set("checkpoint[updated_at]", checkpoint.updated_at);
      url.searchParams.set("checkpoint[id]", checkpoint.id);
    }

    const response = await fetch(url, {
      headers: { Accept: "application/json" },
      credentials: "same-origin",
    });
    if (!response.ok) throw new Error(`pull failed: ${response.status}`);

    const body = await response.json();
    const documents = body.documents || [];

    await cacheDocuments(documents);
    if (body.accounts) await saveAccounts(body.accounts);

    const nextCheckpoint = body.checkpoint;
    const advanced = nextCheckpoint?.id && (!checkpoint || nextCheckpoint.id !== checkpoint.id);

    if (advanced) {
      checkpoint = nextCheckpoint;
      await saveCheckpoint(checkpoint);
    }

    if (documents.length < PULL_BATCH_SIZE || !advanced) break;
  }
}

export async function pushQueuedWrites() {
  const queued = await getQueuedWrites();
  if (!queued.length) return { applied: 0, rejected: 0 };

  // Se manda solo lo que el endpoint espera: los flags locales de UI
  // (por ejemplo __pending) no viajan al server.
  const rows = queued.map((doc) => ({
    id: doc.id,
    account_id: doc.account_id,
    name: doc.name,
    date: doc.date,
    amount: doc.amount,
    currency: doc.currency,
    notes: doc.notes,
  }));

  const response = await fetch("/sync/transactions/push", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Accept: "application/json",
      "X-CSRF-Token": csrfToken(),
    },
    credentials: "same-origin",
    body: JSON.stringify({ rows }),
  });
  if (!response.ok) throw new Error(`push failed: ${response.status}`);

  const body = await response.json();
  const applied = body.applied || [];
  const rejected = body.rejected || [];

  for (const id of applied) {
    await deleteQueuedWrite(id);
  }

  // Las filas rechazadas quedan en la cola a propósito: se muestran como
  // pendientes en la UI en vez de desaparecer sin aviso.
  return { applied: applied.length, rejected: rejected.length };
}

export async function syncNow() {
  if (!navigator.onLine) return;

  await pushQueuedWrites();
  await pullTransactions();
}
