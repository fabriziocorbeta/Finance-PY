// CD & Co ERP — DASHBOARD
// ====================================

// ══════════════════════════════════════════
// DASHBOARD
// ══════════════════════════════════════════
function renderDashboard(){
  if(typeof renderEtherealStats !== 'function') return;
  renderEtherealStats();
  renderEtherealCharts();
  renderEtherealRecentTxs();
  renderEtherealCardsStock();
  renderEtherealSubs();
  if(typeof renderBudgetsSummary === 'function') renderBudgetsSummary();
  if(typeof renderGoalsSummary === 'function') renderGoalsSummary();
}

function renderEtherealStats(){
  const txs = S.txs;
  const fxRate = (typeof FX !== 'undefined' && FX.buy) ? FX.buy : 7200;
  
  let cU=0, cG=0; txs.forEach(t=>t.cur==='₲'?cG++:cU++); const dCur = cG>cU?'₲':'$';
  
  // Total Balance
  const bU = txs.filter(t=>t.cur==='$').reduce((a,t)=>a+(t.type==='income'||t.type==='transfer-in'?t.amount:-t.amount), 0);
  const bP = txs.filter(t=>t.cur==='₲').reduce((a,t)=>a+(t.type==='income'||t.type==='transfer-in'?t.amount:-t.amount), 0);
  const eqTotal = dCur==='₲' ? bP + (bU * fxRate) : bU + (bP / fxRate);
  
  if(g('d-total-balance')) g('d-total-balance').textContent = fmt(eqTotal, dCur);
  
  // Weekly Metrics
  const now = new Date();
  const currWkStart = new Date(now.setDate(now.getDate() - now.getDay() + 1)).toISOString().slice(0,10);
  const currWkEnd = new Date(now.setDate(now.getDate() + 6)).toISOString().slice(0,10);
  
  const prevWkDate = new Date(); prevWkDate.setDate(prevWkDate.getDate()-7);
  const prevWkStart = new Date(prevWkDate.setDate(prevWkDate.getDate() - prevWkDate.getDay() + 1)).toISOString().slice(0,10);
  const prevWkEnd = new Date(prevWkDate.setDate(prevWkDate.getDate() + 6)).toISOString().slice(0,10);
  
  let wInc=0, wExp=0, pInc=0, pExp=0;
  txs.forEach(t=>{
    const isAdj = t.desc.toLowerCase().includes('ajuste') || t.cat.toLowerCase().includes('ajuste') || (t.cat === 'Otros Ingresos' && t.amount > 500000);
    if (isAdj) return;
    const amt = t.cur===dCur ? t.amount : (dCur==='₲' ? t.amount*fxRate : t.amount/fxRate);
    if(t.date >= currWkStart && t.date <= currWkEnd) {
      if(t.type==='income'||t.type==='transfer-in') wInc+=amt; else if(t.type==='expense') wExp+=amt;
    }
    if(t.date >= prevWkStart && t.date <= prevWkEnd) {
      if(t.type==='income'||t.type==='transfer-in') pInc+=amt; else if(t.type==='expense') pExp+=amt;
    }
  });
  
  if(g('d-wk-inc')) g('d-wk-inc').textContent = fmt(wInc, dCur);
  if(g('d-wk-exp')) g('d-wk-exp').textContent = fmt(wExp, dCur);
  
  const getVarHtml = (curr, prev, isExp) => {
    if(prev===0) return curr>0 ? `<span style="color:var(--pos);font-size:.65rem;border-radius:4px;padding:2px 6px;background:var(--pb)">+100% vs previa</span>` : '';
    const pct = ((curr-prev)/prev)*100;
    const isP = pct>0;
    const color = isExp ? (isP?'var(--neg)':'var(--pos)') : (isP?'var(--pos)':'var(--neg)');
    const bg = isExp ? (isP?'var(--nb)':'var(--pb)') : (isP?'var(--pb)':'var(--nb)');
    return `<span style="color:${color};font-size:.65rem;border-radius:4px;padding:2px 6px;background:${bg}">${isP?'+':''}${pct.toFixed(0)}% vs previa</span>`;
  };
  if(g('d-wk-inc-var')) g('d-wk-inc-var').innerHTML = getVarHtml(wInc, pInc, false);
  if(g('d-wk-exp-var')) g('d-wk-exp-var').innerHTML = getVarHtml(wExp, pExp, true);
}

let dRevFlowPeriod = 'month';
window.setDashboardFlowPer = function(p) {
  dRevFlowPeriod = p;
  document.querySelectorAll('#d-rf-mo, #d-rf-wk').forEach(b=>b.classList.remove('on'));
  const el = document.getElementById(p==='month'?'d-rf-mo':'d-rf-wk');
  if(el) el.classList.add('on');
  renderEtherealCharts();
};

let dRevChart = null;
let dExpChart = null;

function renderEtherealCharts() {
  const fxRate = (typeof FX !== 'undefined' && FX.buy) ? FX.buy : 7200;
  let cU=0, cG=0; S.txs.forEach(t=>t.cur==='₲'?cG++:cU++); const dCur = cG>cU?'₲':'$';
  
  // Get theme colors
  const style = getComputedStyle(document.body);
  const colorG2 = style.getPropertyValue('--g2').trim() || '#c9960c';
  const colorBG5 = style.getPropertyValue('--bg5').trim() || 'rgba(255,255,255,0.1)';
  const colorMU = style.getPropertyValue('--mu').trim() || '#8a8278';
  const colorCR = style.getPropertyValue('--cr').trim() || '#fff';

  if(g('d-revenue-chart') && window.Chart) {
    const lbs=[], incs=[], exps=[];
    if(dRevFlowPeriod === 'month') {
      for(let i=5; i>=0; i--){
        const d = new Date(); d.setMonth(d.getMonth()-i);
        const k = d.getFullYear()+'-'+String(d.getMonth()+1).padStart(2,'0');
        lbs.push(d.toLocaleString('es',{month:'short'}));
        let tI=0, tE=0;
        S.txs.filter(t=> {
          const isAdj = t.desc.toLowerCase().includes('ajuste') || t.cat.toLowerCase().includes('ajuste') || (t.cat === 'Otros Ingresos' && t.amount > 500000);
          return mkey(t.date)===k && !isAdj;
        }).forEach(t=>{ const a=t.cur===dCur?t.amount:(dCur==='₲'?t.amount*fxRate:t.amount/fxRate); if(t.type==='income')tI+=a; else if(t.type==='expense')tE+=a; });
        incs.push(tI); exps.push(tE);
      }
    } else {
      for(let i=5; i>=0; i--){
        const d = new Date(); d.setDate(d.getDate() - (i*7));
        lbs.push('Sem '+(5-i)); 
        const wS = new Date(d.setDate(d.getDate() - d.getDay() + 1)).toISOString().slice(0,10);
        const wE = new Date(d.setDate(d.getDate() + 6)).toISOString().slice(0,10);
        let tI=0, tE=0;
        S.txs.filter(t=> {
          const isAdj = t.desc.toLowerCase().includes('ajuste') || t.cat.toLowerCase().includes('ajuste') || (t.cat === 'Otros Ingresos' && t.amount > 500000);
          return t.date>=wS && t.date<=wE && !isAdj;
        }).forEach(t=>{ const a=t.cur===dCur?t.amount:(dCur==='₲'?t.amount*fxRate:t.amount/fxRate); if(t.type==='income')tI+=a; else if(t.type==='expense')tE+=a; });
        incs.push(tI); exps.push(tE);
      }
    }
    
    if(dRevChart) dRevChart.destroy();
    const ctxR = document.getElementById('d-revenue-chart').getContext('2d');
    dRevChart = new Chart(ctxR, {
      type: 'bar',
      data: { labels: lbs, datasets: [
        { label: 'Ingresos', data: incs, backgroundColor: colorG2, borderRadius: 4 },
        { label: 'Gastos', data: exps, backgroundColor: colorBG5, borderRadius: 4 }
      ]},
      options: { 
        responsive: true, maintainAspectRatio: false, 
        plugins: { legend: { display: false } },
        scales: { 
          x: { grid: { display: false }, ticks: { color: colorMU, font: { size: 10 } } }, 
          y: { display: false } 
        }
      }
    });
  }
  
  if(g('d-expense-donut') && window.Chart) {
    const tm = thisMo();
    const catSums = {};
    let totalExp = 0;
    
    // Find predominant
    let cU_exp=0, cG_exp=0;
    S.txs.filter(t=>mkey(t.date) === tm).forEach(t=>t.cur==='₲'?cG_exp++:cU_exp++);
    const dCur_exp = cG_exp>cU_exp ? '₲':'$';
    
    S.txs.forEach(t=>{
      const isAdj = t.desc.toLowerCase().includes('ajuste') || t.cat.toLowerCase().includes('ajuste') || (t.cat === 'Otros Ingresos' && t.amount > 500000);
      if(t.type==='expense' && mkey(t.date) === tm && !isAdj) {
        const amt = t.cur === dCur_exp ? t.amount : (dCur_exp==='₲' ? t.amount*fxRate : t.amount/fxRate);
        catSums[t.cat] = (catSums[t.cat]||0) + amt;
        totalExp += amt;
      }
    });
    
    const sorted = Object.entries(catSums).sort((a,b)=>b[1]-a[1]).slice(0,4);
    const other = Object.entries(catSums).sort((a,b)=>b[1]-a[1]).slice(4).reduce((a,c)=>a+c[1],0);
    if(other>0) sorted.push(['Otras', other]);
    
    if(g('d-expense-list')) {
      if(!sorted.length) g('d-expense-list').innerHTML = `<div style="color:var(--mu);text-align:center">Sin gastos</div>`;
      else g('d-expense-list').innerHTML = sorted.map(c=> {
        const p = totalExp>0 ? Math.round((c[1]/totalExp)*100) : 0;
        return `<div style="display:flex;justify-content:space-between;color:${colorCR}"><span>${c[0]}</span><span style="color:var(--mu)">${p}%</span></div>`;
      }).join('');
    }
    
    if(dExpChart) dExpChart.destroy();
    const ctxE = document.getElementById('d-expense-donut').getContext('2d');
    
    // Generate donut palette based on accent
    const donutPalette = [colorG2, '#a37a0a', '#7d5d08', '#574005', '#302402', colorBG5];

    dExpChart = new Chart(ctxE, {
      type: 'doughnut',
      data: { labels: sorted.map(c=>c[0]), datasets: [{ data: sorted.map(c=>c[1]), backgroundColor: donutPalette, borderWidth:0 }] },
      options: { cutout: '75%', responsive: true, maintainAspectRatio: false, plugins: { legend: { display: false } } }
    });
  }
}

function renderEtherealRecentTxs() {
  const el = g('d-recent-txs');
  if(!el) return;
  const recent = [...S.txs].sort((a,b)=>new Date(b.date)-new Date(a.date)).slice(0,5);
  if(!recent.length){ el.innerHTML='<div style="font-size:.7rem;color:var(--mu)">Sin transacciones</div>'; return; }
  el.innerHTML = recent.map(tx=>`
    <div style="display:flex;align-items:center;gap:12px;padding:6px 0">
      <div style="width:32px;height:32px;border-radius:16px;background:${tx.type==='income'?'var(--pb)':'var(--bg4)'};display:flex;align-items:center;justify-content:center;font-size:14px;flex-shrink:0">${tx.type==='income'?'↓':'↑'}</div>
      <div style="flex:1;min-width:0"><div style="font-size:.75rem;color:var(--cr);white-space:nowrap;overflow:hidden;text-overflow:ellipsis">${tx.desc}</div><div style="font-size:.6rem;color:var(--mu);font-family:var(--fm)">${fmtDate(tx.date)}</div></div>
      <div style="font-family:var(--fm);font-size:.8rem;color:${tx.type==='income'?'var(--pos)':'var(--cr)'}">${tx.type==='income'?'+':'-'}${fmt(tx.amount,tx.cur)}</div>
    </div>`).join('');
}

function renderEtherealCardsStock() {
  const el = g('d-my-cards-stack');
  if(!el) return;
  if(!S.cards || !S.cards.length) { el.innerHTML='<div style="font-size:.7rem;color:var(--mu);text-align:center;padding:12px">No hay tarjetas registradas</div>'; return; }
  
  let html = '';
  const cards = S.cards.slice(0,3);
  cards.forEach((c, i) => {
    const isTop = i===cards.length-1;
    const ty = i * 20; 
    const sc = 1 - ((cards.length-1 - i)*0.05); 
    const zi = i;
    html += `
      <div class="eth-card-stack-item" style="transform: translateY(${ty}px) scale(${sc}); z-index: ${zi}">
         <div style="display:flex;justify-content:space-between;align-items:flex-start">
            <span style="font-size:.8rem;font-weight:600;letter-spacing:1px">${c.brand||c.name}</span>
            <span style="font-size:.65rem;color:var(--mu)">Límite: ${fmt(c.initialBalance||0, c.cur)}</span>
         </div>
         <div>
            <div style="font-family:var(--fm);letter-spacing:2px;font-size:1rem;margin-bottom:4px">**** **** **** ${c.last4 || '----'}</div>
            <div style="display:flex;justify-content:space-between;font-size:.65rem;color:var(--mu)"><span style="flex:1;white-space:nowrap;overflow:hidden">${c.name}</span><span style="margin-left:8px">EXP ${c.exp || '--/--'}</span></div>
         </div>
      </div>
    `;
  });
  el.innerHTML = html;
}

function renderEtherealSubs() {
  const el = g('d-active-subs');
  if(!el) return;
  const subs = (S.subscriptions||[]).filter(s=>s.active).sort((a,b)=>new Date(a.nextDate||0)-new Date(b.nextDate||0)).slice(0,4);
  if(!subs.length){ el.innerHTML='<div style="font-size:.7rem;color:var(--mu);text-align:center">Sin suscripciones</div>'; return; }
  el.innerHTML = subs.map(s=>`
    <div style="display:flex;align-items:center;gap:12px">
      <div style="width:36px;height:36px;border-radius:10px;background:var(--bg4);display:flex;align-items:center;justify-content:center;font-size:18px">${s.icon||'💎'}</div>
      <div style="flex:1"><div style="font-size:.8rem;color:var(--cr)">${s.name}</div><div style="font-size:.6rem;color:var(--mu)">Próximo: ${fmtDate(s.nextDate)}</div></div>
      <div style="font-size:.8rem;font-weight:600;color:var(--cr)">-${fmt(s.amount, s.cur)}</div>
    </div>
  `).join('');
}

function renderEtherealStockAlerts() {
  const el=g('stock-alerts');
  if(!el) return;
  const alerts=S.products.filter(p=>p.stock<=p.minStock);
  if(!alerts.length){el.innerHTML='<div class="tbl-empty" style="padding:12px;font-size:.74rem">✓ Todo en orden</div>';return}
  el.innerHTML=alerts.map(p=>{
    const isOut=p.stock<=0;
    return `<div style="display:flex;align-items:center;gap:9px;padding:7px 0;border-bottom:1px solid var(--bg5)">
      <div style="font-size:18px">${isOut?'🔴':'🟡'}</div>
      <div style="flex:1;min-width:0"><div style="font-size:.74rem;font-weight:500;color:var(--cr)">${p.name}</div><div style="font-size:.6rem;font-family:var(--fm);color:var(--m3)">${p.sku}</div></div>
      <div style="text-align:right">
        <div style="font-family:var(--fm);font-size:.76rem;color:${isOut?'#d47a7a':'#e8b124'}">${isOut?'Sin stock':p.stock+' u.'}</div>
        <button class="btn btn-s" style="font-size:.58rem;padding:3px 7px;margin-top:3px" onclick="openStockModal('${p.id}')">Ajustar</button>
      </div>
    </div>`;
  }).join('');
}
