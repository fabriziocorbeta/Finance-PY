// CD & Co ERP — SUPABASE SYNCHRONIZATION
// ====================================

// Supabase client initializeation
// Ensure you have Supabase JS CDN loaded in index.html
// e.g., <script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>

// Place your Supabase URL and Anon Key here:
const SUPABASE_URL = 'https://TU-PROYECTO.supabase.co';
const SUPABASE_KEY = 'TU-ANON-KEY';

let supabaseClient = null;

if (typeof supabase !== 'undefined') {
  supabaseClient = supabase.createClient(SUPABASE_URL, SUPABASE_KEY);
} else {
  console.warn("Supabase SDK no está cargado.");
}

// ══════════════════════════════════════════
// MAPEO DE TABLAS INTERNAS (S.* -> Tabla Supabase)
// ══════════════════════════════════════════
const TABLE_MAP = {
  accounts: 'accounts',
  cards: 'cards',
  debts: 'debts',
  budgets: 'budgets',
  subscriptions: 'subscriptions',
  products: 'products',
  txs: 'txs',
  sales: 'sales',
  orders: 'orders',
  contacts: 'contacts'
};

// ══════════════════════════════════════════
// RUTINAS MAESTRAS DE SINCRONIZACIÓN
// ══════════════════════════════════════════

/**
 * Empuja todo el estado local actual (Upsert) hacia las tablas de Supabase.
 * Se asume que el usuario local ya tiene un ID si está logeado (S.uid o user.uid).
 */
async function pushToSupabase(silent = true) {
  if (!supabaseClient) return;
  // CD&Co currently doesn't enforce strict Supabase auth, but assume a user concept 
  // exists or will exist. For a local system syncing, we'll try to find an active session.
  const { data: { session } } = await supabaseClient.auth.getSession();
  if (!session) {
    if (!silent) console.log('No active session for pushToSupabase');
    return;
  }
  const userId = session.user.id;

  try {
    // 1. Sync App State (Config, EMPRESA)
    const statePayload = {
      empresa: typeof EMPRESA !== 'undefined' ? EMPRESA : {},
      appMode: S.appMode || 'full',
      plan: S.plan || 'free'
    };
    
    await supabaseClient.from('app_state').upsert({
      user_id: userId,
      payload: statePayload,
      updated_at: new Date()
    });

    // 2. Sync Arrays
    const promises = [];
    for (const sKey in TABLE_MAP) {
      const table = TABLE_MAP[sKey];
      const records = S[sKey] || [];
      
      if (records.length > 0) {
        // Enforce user_id attachment
        const preppedRecords = records.map(r => ({ ...r, user_id: userId }));
        
        // Supabase limit per upsert is large, but bulk insert is fine
        promises.push(
          supabaseClient.from(table).upsert(preppedRecords)
        );
      }
    }

    await Promise.all(promises);
    if (!silent) console.log('◆ Sincronización a Supabase completada.');
  } catch (err) {
    console.error('Error sincronizando a Supabase:', err);
  }
}

/**
 * Descarga todo el estado desde Supabase y sobrescribe el caché de memoria (S.*)
 * Invocado principalmente al arrancar la app.
 */
async function pullFromSupabase() {
  if (!supabaseClient) return;
  const { data: { session } } = await supabaseClient.auth.getSession();
  if (!session) return;
  
  try {
    if(typeof showLoad === 'function') showLoad();
    
    // 1. App State
    const { data: stData } = await supabaseClient.from('app_state').select('*').single();
    if (stData && stData.payload) {
      if (typeof EMPRESA !== 'undefined') {
        Object.assign(EMPRESA, stData.payload.empresa || {});
      }
      S.appMode = stData.payload.appMode || 'full';
      S.plan = stData.payload.plan || 'free';
    }

    // 2. Table Data
    const promises = Object.keys(TABLE_MAP).map(async (sKey) => {
      const table = TABLE_MAP[sKey];
      const { data, error } = await supabaseClient.from(table).select('*');
      if (!error && data) {
        // Strip out the user_id column locally to keep matching memory structures clean
        S[sKey] = data.map(r => {
          const { user_id, created_at, ...rest } = r;
          return rest;
        });
      }
    });

    await Promise.all(promises);
    
    // Forzar la reescritura de LocalStorage
    try{ localStorage.setItem('cdco_db', JSON.stringify(S)); } catch(e){}
    try{ localStorage.setItem('cdco_empresa', JSON.stringify(EMPRESA)); } catch(e){}

    console.log('◆ Descarga desde Supabase completada.');
    if(typeof hideLoad === 'function') hideLoad();
    
    // Refrescar UI si estamos montados
    if(typeof renderAll === 'function') renderAll();
    
  } catch (err) {
    console.error('Error descargando de Supabase:', err);
    if(typeof hideLoad === 'function') hideLoad();
  }
}
