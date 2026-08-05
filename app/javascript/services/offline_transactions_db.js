// Almacenamiento offline de transacciones.
//
// Mismo patrón de callbacks-envueltos-en-Promise que services/offline_sales_db.js,
// que ya corre en producción para la cola offline de Ventas. Sin dependencias
// externas a propósito: este proyecto no tiene bundler, todo el JS va por importmap.
//
// Tres stores:
//   transactions_cache        -> documentos traídos del server (lectura offline)
//   pending_transaction_writes -> cola de escrituras sin sincronizar
//   sync_meta                  -> checkpoint de replicación + cuentas cacheadas

const DB_NAME = "financespy_offline_transactions";
const DB_VERSION = 1;
const CACHE_STORE = "transactions_cache";
const QUEUE_STORE = "pending_transaction_writes";
const META_STORE = "sync_meta";

function openDb() {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DB_NAME, DB_VERSION);
    request.onupgradeneeded = (event) => {
      const db = event.target.result;
      if (!db.objectStoreNames.contains(CACHE_STORE)) {
        const cache = db.createObjectStore(CACHE_STORE, { keyPath: "id" });
        cache.createIndex("by_date", "date");
      }
      if (!db.objectStoreNames.contains(QUEUE_STORE)) {
        db.createObjectStore(QUEUE_STORE, { keyPath: "id" });
      }
      if (!db.objectStoreNames.contains(META_STORE)) {
        db.createObjectStore(META_STORE, { keyPath: "key" });
      }
    };
    request.onsuccess = (event) => resolve(event.target.result);
    request.onerror = (event) => reject(event.target.error);
  });
}

// Corre `work` dentro de una transacción de IndexedDB y resuelve recién en
// `oncomplete`, para que los writes estén realmente confirmados antes de seguir.
function withStore(storeName, mode, work) {
  return openDb().then(
    (db) =>
      new Promise((resolve, reject) => {
        const tx = db.transaction(storeName, mode);
        const store = tx.objectStore(storeName);
        const holder = {};

        try {
          work(store, holder);
        } catch (error) {
          reject(error);
          return;
        }

        tx.oncomplete = () => resolve(holder.value);
        tx.onerror = (event) => reject(event.target.error);
        tx.onabort = (event) => reject(event.target.error);
      })
  );
}

function readInto(holder, request) {
  request.onsuccess = (event) => {
    holder.value = event.target.result;
  };
}

export function cacheDocuments(docs) {
  if (!docs || !docs.length) return Promise.resolve();

  return withStore(CACHE_STORE, "readwrite", (store) => {
    for (const doc of docs) store.put(doc);
  });
}

export function getCachedTransactions(limit = 100) {
  return withStore(CACHE_STORE, "readonly", (store, holder) => {
    readInto(holder, store.getAll());
  }).then((all) =>
    (all || [])
      .slice()
      .sort((a, b) => {
        if (a.date === b.date) return 0;
        return a.date < b.date ? 1 : -1;
      })
      .slice(0, limit)
  );
}

export function queueWrite(doc) {
  return withStore(QUEUE_STORE, "readwrite", (store) => {
    store.put(doc);
  });
}

export function getQueuedWrites() {
  return withStore(QUEUE_STORE, "readonly", (store, holder) => {
    readInto(holder, store.getAll());
  }).then((all) => all || []);
}

export function deleteQueuedWrite(id) {
  return withStore(QUEUE_STORE, "readwrite", (store) => {
    store.delete(id);
  });
}

export function saveCheckpoint(checkpoint) {
  return withStore(META_STORE, "readwrite", (store) => {
    store.put({ key: "checkpoint", value: checkpoint });
  });
}

export function getCheckpoint() {
  return withStore(META_STORE, "readonly", (store, holder) => {
    readInto(holder, store.get("checkpoint"));
  }).then((record) => (record ? record.value : null));
}

export function saveAccounts(accounts) {
  return withStore(META_STORE, "readwrite", (store) => {
    store.put({ key: "accounts", value: accounts });
  });
}

export function getAccounts() {
  return withStore(META_STORE, "readonly", (store, holder) => {
    readInto(holder, store.get("accounts"));
  }).then((record) => (record ? record.value : []));
}
