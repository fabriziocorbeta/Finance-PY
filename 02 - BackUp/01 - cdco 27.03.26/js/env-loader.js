// ══════════════════════════════════════════
// 🔐 ENV LOADER - Carga variables de entorno
// ══════════════════════════════════════════
// Este script carga variables de entorno desde:
// 1. Variables globales window.__ENV__ (inyectadas por el servidor)
// 2. localStorage (fallback para desarrollo)

(function() {
  // Asegurar que window.__ENV__ existe
  if (!window.__ENV__) {
    window.__ENV__ = {};
  }

  // Si las variables ya fueron inyectadas por el servidor, usarlas
  if (window.__ENV__.SUPABASE_URL && window.__ENV__.SUPABASE_ANON_KEY) {
    console.log('✅ Variables de entorno cargadas desde servidor');
    return;
  }

  // Fallback: intentar cargar desde localStorage (solo para desarrollo local)
  if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
    const sb_url = localStorage.getItem('sb_url');
    const sb_key = localStorage.getItem('sb_key');

    if (sb_url && sb_key) {
      window.__ENV__.SUPABASE_URL = sb_url;
      window.__ENV__.SUPABASE_ANON_KEY = sb_key;
      console.log('✅ Variables de entorno cargadas desde localStorage');
    } else {
      console.log('💡 [Dev] Credenciales de Supabase no encontradas');
      console.log('💡 [Dev] Cargalas con: localStorage.setItem("sb_url", "..."); localStorage.setItem("sb_key", "...");');
    }
  }
})();
