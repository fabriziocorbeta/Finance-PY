const http = require('http');
const fs = require('fs');
const path = require('path');
const url = require('url');
const backup = require('./backup');

const PORT = 3000;
const PROJECT_DIR = __dirname;

// 🔐 Cargar variables de entorno desde .env.local
function loadEnvFile() {
  const envPath = path.join(PROJECT_DIR, '.env.local');
  const env = {};

  try {
    if (fs.existsSync(envPath)) {
      const envContent = fs.readFileSync(envPath, 'utf-8');
      const lines = envContent.split('\n');

      lines.forEach(line => {
        // Ignorar comentarios y líneas vacías
        if (line.startsWith('#') || !line.trim()) return;

        const [key, ...valueParts] = line.split('=');
        const value = valueParts.join('=').trim();

        // Remover comillas si existen
        env[key.trim()] = value.replace(/^["']|["']$/g, '');
      });

      console.log('✅ Variables de entorno cargadas desde .env.local');
      return env;
    }
  } catch (err) {
    console.warn('⚠️ No se pudo leer .env.local:', err.message);
  }

  return env;
}

const envVars = loadEnvFile();

// ══════════════════════════════════════════
// MANEJADOR DE API ENDPOINTS
// ══════════════════════════════════════════
async function handleApiRequest(pathname, method, body) {
  // GET /api/backup/status — obtener estado del último backup
  if (pathname === '/api/backup/status' && method === 'GET') {
    const status = await backup.getBackupStatus();
    return {
      statusCode: 200,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(status)
    };
  }

  // POST /api/backup/now — forzar backup inmediato
  if (pathname === '/api/backup/now' && method === 'POST') {
    const result = await backup.generateBackup(envVars.SUPABASE_URL, envVars.SUPABASE_ANON_KEY);
    return {
      statusCode: result.success ? 200 : 500,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(result)
    };
  }

  // Endpoint no encontrado
  return {
    statusCode: 404,
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ error: 'Endpoint no encontrado' })
  };
}

// Inyectar variables de entorno en HTML
function injectEnv(htmlContent) {
  const envObj = JSON.stringify({
    SUPABASE_URL: envVars.SUPABASE_URL || '',
    SUPABASE_ANON_KEY: envVars.SUPABASE_ANON_KEY || ''
  });

  const envScript = `
    <script>
      window.__ENV__ = ${envObj};
      console.log('🔐 [Server] Variables de entorno inyectadas', window.__ENV__);
    </script>
  `;

  // Inyectar antes de </head>
  const updated = htmlContent.replace('</head>', envScript + '</head>');

  if (!updated.includes(envScript.trim())) {
    console.warn('⚠️ [Server] Advertencia: Las variables NO se inyectaron correctamente');
  } else {
    console.log('✅ [Server] Variables inyectadas en HTML');
  }

  return updated;
}

const server = http.createServer(async (req, res) => {
  const parsedUrl = url.parse(req.url, true);
  const pathname = parsedUrl.pathname;

  // 🔌 PROCESAR ENDPOINTS DE API
  if (pathname.startsWith('/api/')) {
    let body = '';
    req.on('data', chunk => body += chunk);
    req.on('end', async () => {
      try {
        const apiResponse = await handleApiRequest(pathname, req.method, body);
        res.writeHead(apiResponse.statusCode, apiResponse.headers);
        res.end(apiResponse.body);
      } catch (err) {
        res.writeHead(500, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: err.message }));
      }
    });
    return;
  }

  // 📄 SERVIR ARCHIVOS ESTÁTICOS
  let filePath = path.join(PROJECT_DIR, pathname);

  // Si es una carpeta, intenta servir index.html
  if (fs.existsSync(filePath) && fs.statSync(filePath).isDirectory()) {
    filePath = path.join(filePath, 'index.html');
  }

  // Si no existe, intenta index.html (para SPA routing)
  if (!fs.existsSync(filePath)) {
    filePath = path.join(PROJECT_DIR, 'index.html');
  }

  fs.readFile(filePath, 'utf-8', (err, data) => {
    if (err) {
      res.writeHead(404, { 'Content-Type': 'text/html' });
      res.end('<h1>404 - Archivo no encontrado</h1>');
      return;
    }

    // Detectar tipo de contenido
    const ext = path.extname(filePath).toLowerCase();
    const contentTypes = {
      '.html': 'text/html; charset=utf-8',
      '.css': 'text/css; charset=utf-8',
      '.js': 'text/javascript; charset=utf-8',
      '.json': 'application/json; charset=utf-8',
      '.png': 'image/png',
      '.jpg': 'image/jpeg',
      '.jpeg': 'image/jpeg',
      '.gif': 'image/gif',
      '.svg': 'image/svg+xml',
      '.woff': 'font/woff',
      '.woff2': 'font/woff2',
      '.ttf': 'font/ttf'
    };

    const contentType = contentTypes[ext] || 'application/octet-stream';

    // Si es HTML, inyectar variables de entorno
    let content = data;
    if (ext === '.html' && typeof data === 'string') {
      content = injectEnv(data);
    }

    res.writeHead(200, {
      'Content-Type': contentType,
      'Access-Control-Allow-Origin': '*',
      'Cache-Control': 'no-cache'
    });
    res.end(content);
  });
});

server.listen(PORT, async () => {
  console.log(`\n🚀 CD & Co ERP - Servidor de desarrollo`);
  console.log(`📍 URL: http://localhost:${PORT}`);
  console.log(`📁 Directorio: ${PROJECT_DIR}`);
  if (envVars.SUPABASE_URL) {
    console.log('✅ Supabase: Configurado');
    // 💾 Iniciar sistema de backup automático
    backup.initBackupScheduler(envVars.SUPABASE_URL, envVars.SUPABASE_ANON_KEY);
  } else {
    console.log('⚠️ Supabase: No configurado (revisa .env.local)');
  }
  console.log('');
});
