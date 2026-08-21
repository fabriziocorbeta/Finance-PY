// CD & Co ERP — CONFIG
// ====================================

// ══════════════════════════════════════════
// ⚙️  CONFIG
// ══════════════════════════════════════════

// 🔐 Variables de entorno (leer de .env.local en desarrollo)
// Para desarrollo local: crea un archivo .env.local con:
//   SUPABASE_URL=https://...
//   SUPABASE_ANON_KEY=sb_...
const SB_URL =
  typeof process !== 'undefined' && process.env?.SUPABASE_URL
    ? process.env.SUPABASE_URL
    : window.__ENV__?.SUPABASE_URL || 'TU_SUPABASE_URL_AQUI';

const SB_KEY =
  typeof process !== 'undefined' && process.env?.SUPABASE_ANON_KEY
    ? process.env.SUPABASE_ANON_KEY
    : window.__ENV__?.SUPABASE_ANON_KEY || 'TU_SUPABASE_ANON_KEY_AQUI';

const STRIPE={pro:'TU_LINK_PRO',business:'TU_LINK_BUSINESS'};
const ANTHROPIC_KEY='TU_ANTHROPIC_KEY_AQUI';

// ✓ Supabase está configurado si URL y KEY no tienen placeholders
const SB_ON = !SB_URL.includes('TU_') && !SB_KEY.includes('TU_');
let sb = null;

if (SB_ON) {
  sb = window.supabase?.createClient(SB_URL, SB_KEY);
  console.log('✅ [Config] Supabase conectado correctamente');
} else {
  console.warn('⚠️ [Config] Supabase NO configurado - usando localStorage');
}

// ══════════════════════════════════════════
// STATE
// ══════════════════════════════════════════
// ── DATOS FISCALES DE LA EMPRESA (editables en configuración) ──
let EMPRESA = {
  nombre: 'CD & Co',
  razonSocial: 'CD & Co S.R.L.',
  ruc: '80123456-7',
  direccion: 'Asunción, Paraguay',
  telefono: '+595 21 000000',
  email: 'info@cd-co.com.py',
  web: 'cd-co.com.py',
  timbrado: '12345678',
  vigenciaDesde: '2024-01-01',
  vigenciaHasta: '2026-12-31',
  nroFacturaInicio: 1,
};
try { const e=localStorage.getItem('cdco_empresa'); if(e) EMPRESA={...EMPRESA,...JSON.parse(e)}; } catch(ex){}

const CATEGORIAS_GASTOS = [
  {id:'c1', name:'Alimentación', icon:'🛒'}, {id:'c2', name:'Transporte', icon:'🚌'},
  {id:'c3', name:'Vivienda', icon:'🏠'}, {id:'c4', name:'Salud', icon:'💊'},
  {id:'c5', name:'Educación', icon:'📚'}, {id:'c6', name:'Entretenimiento', icon:'🍿'},
  {id:'c7', name:'Servicios', icon:'⚡'}, {id:'c8', name:'Ropa', icon:'👕'},
  {id:'c9', name:'Tecnología', icon:'💻'}, {id:'c10', name:'Viajes', icon:'✈️'},
  {id:'c11', name:'Restaurantes', icon:'🍽️'}, {id:'c12', name:'Compras', icon:'🛍️'},
  {id:'c20', name:'Otros Gastos', icon:'🔹'}
];
const CATEGORIAS_INGRESOS = [
  {id:'i1', name:'Salario', icon:'💰'}, {id:'i2', name:'Freelance', icon:'💻'},
  {id:'i3', name:'Inversiones', icon:'📈'}, {id:'i4', name:'Negocio', icon:'🏢'},
  {id:'i5', name:'Alquiler', icon:'🔑'}, {id:'i6', name:'Regalo', icon:'🎁'},
  {id:'i7', name:'Venta', icon:'🛒'}, {id:'i8', name:'Reembolso', icon:'🔙'},
  {id:'i9', name:'Otros Ingresos', icon:'💵'}
];

let S={
  txs:[], products:[], sales:[], orders:[], contacts:[], cards:[], debts:[], accounts:[], budgets:[], subscriptions:[], goals:[], historical:[], receivables:[],
  customCategories: {gastos:[], ingresos:[]},
  fltTx:'all', fltInv:'all', fltSale:'all', fltOrd:'all', fltCon:'all', fltInv2:'all',
  user:null, plan:'pro',
  curPage:'dashboard',
  appMode:'full'
};
let editIds={tx:null,prod:null,sale:null,order:null,con:null};
let txType='income';
let saleLines=[], orderLines=[], stockProdId=null;
let recvOrderId=null;
let lm=false, lc2=null, dnc=null;
let FX={buy:0,sell:0,ts:null,dir:'usd2pyg',manual:false};
let selPK='pro';

// Helpers
function g(id){return document.getElementById(id)}

// ══════════════════════════════════════════
// SUPABASE CRUD FUNCTIONS
// ══════════════════════════════════════════

// 📝 INSERT or UPDATE product in Supabase
async function sbSaveProduct(prod, isNew = true) {
  if (!SB_ON) {
    console.warn('⚠️ Supabase NO configurado - solo localStorage');
    return null;
  }

  try {
    // Preparar datos para Supabase
    const data = {
      sku: prod.sku,
      name: prod.name,
      category: prod.cat,
      buy_price: prod.buyPrice,
      sell_price: prod.sellPrice,
      stock: prod.stock,
      min_stock: prod.minStock,
      variant: prod.variant || null,
      serial_number: prod.serialNumber || null,
      desc: prod.desc || null,
      cur: prod.cur || '₲',
      exchange_rate: prod.exchangeRate || null
    };

    let result;
    if (isNew) {
      // INSERT nuevo producto
      const response = await fetch(`${SB_URL}/rest/v1/products`, {
        method: 'POST',
        headers: {
          'apikey': SB_KEY,
          'Authorization': `Bearer ${SB_KEY}`,
          'Content-Type': 'application/json',
          'Prefer': 'return=representation'
        },
        body: JSON.stringify(data)
      });

      if (!response.ok) {
        const err = await response.json();
        console.error('❌ Error al insertar en Supabase:', err);
        toast('❌ Error al guardar en BD: ' + (err.message || 'Error desconocido'));
        return null;
      }

      result = await response.json();
      console.log('✅ Producto insertado en Supabase:', result[0]);
      return result[0];
    } else {
      // UPDATE producto existente
      const response = await fetch(`${SB_URL}/rest/v1/products?id=eq.${prod.id}`, {
        method: 'PATCH',
        headers: {
          'apikey': SB_KEY,
          'Authorization': `Bearer ${SB_KEY}`,
          'Content-Type': 'application/json',
          'Prefer': 'return=representation'
        },
        body: JSON.stringify(data)
      });

      if (!response.ok) {
        const err = await response.json();
        console.error('❌ Error al actualizar en Supabase:', err);
        toast('❌ Error al actualizar: ' + (err.message || 'Error desconocido'));
        return null;
      }

      result = await response.json();
      console.log('✅ Producto actualizado en Supabase:', result[0]);
      return result[0];
    }
  } catch (err) {
    console.error('❌ Exception:', err.message);
    toast('❌ Error de conexión: ' + err.message);
    return null;
  }
}

// 🗑️ DELETE product from Supabase
async function sbDeleteProduct(prodId) {
  if (!SB_ON) {
    console.warn('⚠️ Supabase NO configurado - solo localStorage');
    return true;
  }

  try {
    const response = await fetch(`${SB_URL}/rest/v1/products?id=eq.${prodId}`, {
      method: 'DELETE',
      headers: {
        'apikey': SB_KEY,
        'Authorization': `Bearer ${SB_KEY}`
      }
    });

    if (!response.ok) {
      const err = await response.json();
      console.error('❌ Error al eliminar:', err);
      toast('❌ Error al eliminar');
      return false;
    }

    console.log('✅ Producto eliminado de Supabase');
    return true;
  } catch (err) {
    console.error('❌ Exception:', err.message);
    return false;
  }
}

// 📥 LOAD all products from Supabase
async function sbLoadProducts() {
  if (!SB_ON) {
    console.warn('⚠️ Supabase NO configurado - usando localStorage');
    return [];
  }

  try {
    const response = await fetch(`${SB_URL}/rest/v1/products?select=*`, {
      method: 'GET',
      headers: {
        'apikey': SB_KEY,
        'Authorization': `Bearer ${SB_KEY}`
      }
    });

    if (!response.ok) {
      const err = await response.json();
      console.error('❌ Error al cargar productos:', err);
      return [];
    }

    const products = await response.json();
    console.log(`✅ ${products.length} productos cargados de Supabase`);

    // Mapear columnas de Supabase a formato local
    return products.map(p => ({
      id: p.id,
      sku: p.sku,
      name: p.name,
      cat: p.category,
      buyPrice: p.buy_price,
      sellPrice: p.sell_price,
      stock: p.stock,
      minStock: p.min_stock,
      variant: p.variant,
      serialNumber: p.serial_number,
      desc: p.desc,
      cur: p.cur || '₲',
      exchangeRate: p.exchange_rate || null
    }));
  } catch (err) {
    console.error('❌ Exception:', err.message);
    return [];
  }
}

// 🔄 SYNC all data from Supabase on app init
async function initSupabase() {
  if (!SB_ON) {
    console.log('⚠️ Supabase NO configurado - usando solo localStorage');
    return;
  }

  console.log('🔄 Sincronizando datos desde Supabase...');

  // Cargar productos
  const sbProducts = await sbLoadProducts();
  if (sbProducts.length > 0) {
    S.products = sbProducts;
    console.log(`✅ Inventario sincronizado: ${sbProducts.length} productos desde BD`);
  }

  // Cargar transacciones
  const sbTransactions = await sbLoadTransactions();
  if (sbTransactions.length > 0) {
    S.txs = sbTransactions;
    console.log(`✅ Transacciones sincronizadas: ${sbTransactions.length} movimientos desde BD`);
  }

  // Cargar ventas
  const sbSales = await sbLoadSales();
  if (sbSales.length > 0) {
    S.sales = sbSales;
    console.log(`✅ Ventas sincronizadas: ${sbSales.length} ventas desde BD`);
  }

  console.log('✅ Sincronización Supabase completada');
}

// ══════════════════════════════════════════
// EXPORT FUNCTIONS
// ══════════════════════════════════════════

// 📊 Generic CSV export function
function exportToCSV(filename, headers, rows) {
  // Crear contenido CSV
  const headerRow = headers.map(h => `"${h}"`).join(',');
  const csvContent = [
    headerRow,
    ...rows.map(row =>
      row.map(cell => {
        // Escapar comillas y saltos de línea
        const val = String(cell || '').replace(/"/g, '""').replace(/\n/g, ' ');
        return `"${val}"`;
      }).join(',')
    )
  ].join('\n');

  // Agregar BOM para que Excel reconozca UTF-8
  const BOM = '\uFEFF';
  const csvBlob = new Blob([BOM + csvContent], { type: 'text/csv;charset=utf-8;' });

  // Crear link y descargar
  const link = document.createElement('a');
  const url = URL.createObjectURL(csvBlob);
  link.setAttribute('href', url);
  link.setAttribute('download', `${filename}.csv`);
  link.style.visibility = 'hidden';
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);

  console.log(`✅ Archivo ${filename}.csv descargado`);
}

// 📦 Export inventory products to CSV
function exportInventoryCSV() {
  if (!S.products || !S.products.length) {
    toast('❌ No hay productos para exportar');
    return;
  }

  const headers = ['SKU', 'Producto', 'Categoría', 'Variante', 'Nº Serial', 'Precio Compra', 'Precio Venta', 'Margen %', 'Stock', 'Stock Mínimo', 'Descripción', 'Moneda'];

  const rows = S.products.map(p => {
    const margin = p.buyPrice > 0 ? Math.round((p.sellPrice - p.buyPrice) / p.buyPrice * 100) : 0;
    return [
      p.sku || '',
      p.name || '',
      p.cat || '',
      p.variant || '',
      p.serialNumber || '',
      p.buyPrice || 0,
      p.sellPrice || 0,
      margin,
      p.stock || 0,
      p.minStock || 0,
      p.desc || '',
      p.cur || '₲'
    ];
  });

  const fecha = new Date().toLocaleDateString('es').replace(/\//g, '-');
  exportToCSV(`Inventario_${fecha}`, headers, rows);
  toast('✅ Inventario exportado a CSV');
}

// 📈 Export profitability data to CSV
function exportProfitabilityCSV() {
  if (!S.products || !S.products.length) {
    toast('❌ No hay productos para exportar');
    return;
  }

  const headers = ['SKU', 'Producto', 'Categoría', 'Precio Compra', 'Precio Venta', 'Margen %', 'Stock', 'Valor Compra Total', 'Valor Venta Total', 'Ganancia Potencial'];

  const rows = S.products.map(p => {
    const margin = p.buyPrice > 0 ? Math.round((p.sellPrice - p.buyPrice) / p.buyPrice * 100) : 0;
    const valueBuy = p.stock * p.buyPrice;
    const valueSell = p.stock * p.sellPrice;
    const profit = valueSell - valueBuy;

    return [
      p.sku || '',
      p.name || '',
      p.cat || '',
      p.buyPrice || 0,
      p.sellPrice || 0,
      margin,
      p.stock || 0,
      valueBuy,
      valueSell,
      profit
    ];
  });

  const fecha = new Date().toLocaleDateString('es').replace(/\//g, '-');
  exportToCSV(`Rentabilidad_${fecha}`, headers, rows);
  toast('✅ Análisis de rentabilidad exportado a CSV');
}

// 💱 CONVERTIR USANDO TASA HISTÓRICA DEL PRODUCTO
// Si el producto tiene exchangeRate guardado, lo usa; sino, usa FX.sell actual
function convertProductAmount(amount, product, fromCur, toCur) {
  if (fromCur === toCur) return amount;

  // Usar tasa histórica del producto o caer a FX.sell actual
  const rate = product.exchangeRate || (FX && FX.sell) || 7200;

  if (fromCur === '$' && toCur === '₲') return amount * rate;
  if (fromCur === '₲' && toCur === '$') return amount / rate;
  return amount;
}

// ══════════════════════════════════════════
// LOAD TRANSACTIONS FROM SUPABASE
// ══════════════════════════════════════════
async function sbLoadTransactions() {
  if (!SB_ON) {
    console.warn('⚠️ Supabase NO configurado - usando localStorage');
    return [];
  }

  try {
    const response = await fetch(`${SB_URL}/rest/v1/transactions?select=*`, {
      method: 'GET',
      headers: {
        'apikey': SB_KEY,
        'Authorization': `Bearer ${SB_KEY}`
      }
    });

    if (!response.ok) {
      const err = await response.json();
      console.error('❌ Error al cargar transacciones:', err);
      return [];
    }

    const transactions = await response.json();
    console.log(`✅ ${transactions.length} transacciones cargadas de Supabase`);

    // Mapear columnas de Supabase a formato local
    return transactions.map(t => ({
      id: t.id,
      type: t.type,
      desc: t.description,
      amount: t.amount,
      cur: t.currency || '$',
      cat: t.category,
      date: t.date,
      icon: t.icon
    }));
  } catch (err) {
    console.error('❌ Exception:', err.message);
    return [];
  }
}

// ══════════════════════════════════════════
// LOAD SALES FROM SUPABASE
// ══════════════════════════════════════════
async function sbLoadSales() {
  if (!SB_ON) {
    console.warn('⚠️ Supabase NO configurado - usando localStorage');
    return [];
  }

  try {
    const response = await fetch(`${SB_URL}/rest/v1/sales?select=*`, {
      method: 'GET',
      headers: {
        'apikey': SB_KEY,
        'Authorization': `Bearer ${SB_KEY}`
      }
    });

    if (!response.ok) {
      const err = await response.json();
      console.error('❌ Error al cargar ventas:', err);
      return [];
    }

    const sales = await response.json();
    console.log(`✅ ${sales.length} ventas cargadas de Supabase`);

    // Mapear columnas de Supabase a formato local
    return sales.map(s => ({
      id: s.id,
      num: s.num,
      items: s.items || [],
      total: s.total,
      currency: s.currency || '$',
      date: s.date,
      client_id: s.client_id,
      status: s.status,
      condicion: s.condicion,
      nro_factura: s.nro_factura,
      notes: s.notes
    }));
  } catch (err) {
    console.error('❌ Exception:', err.message);
    return [];
  }
}

