// CD & Co ERP — CONFIG
// ====================================

// ══════════════════════════════════════════
// ⚙️  CONFIG
// ══════════════════════════════════════════
const SB_URL='TU_SUPABASE_URL_AQUI';
const SB_KEY='TU_SUPABASE_ANON_KEY_AQUI';
const STRIPE={pro:'TU_LINK_PRO',business:'TU_LINK_BUSINESS'};
const ANTHROPIC_KEY='TU_ANTHROPIC_KEY_AQUI';
const SB_ON=!SB_URL.includes('TU_');
let sb=null; if(SB_ON)sb=window.supabase?.createClient(SB_URL,SB_KEY);

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

