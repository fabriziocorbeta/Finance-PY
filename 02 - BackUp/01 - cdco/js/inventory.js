// CD & Co ERP — INVENTORY
// ====================================

// ══════════════════════════════════════════
// INVENTORY
// ══════════════════════════════════════════
let invFlt='all';
function setInvFlt(f,btn){invFlt=f;document.querySelectorAll('#page-inventory .flt').forEach(b=>b.classList.remove('on'));btn.classList.add('on');renderInventory()}
function renderInventory(){
  const q=(g('inv-search')?.value||'').toLowerCase();
  const cat=g('inv-cat-flt')?.value||'';
  let prods=[...S.products];
  if(invFlt==='low')prods=prods.filter(p=>p.stock>0&&p.stock<=p.minStock);
  else if(invFlt==='out')prods=prods.filter(p=>p.stock<=0);
  if(q)prods=prods.filter(p=>p.name.toLowerCase().includes(q)||p.sku.toLowerCase().includes(q)||p.cat.toLowerCase().includes(q));
  if(cat)prods=prods.filter(p=>p.cat===cat);
  const grid=g('inv-grid');
  if(!prods.length){grid.innerHTML='<div class="tbl-empty" style="grid-column:1/-1;padding:32px">Sin productos. Agregá el primero.</div>';return}
  grid.innerHTML=prods.map(p=>{
    const sup=S.contacts.find(c=>c.id===p.sup);
    const stockClass=p.stock<=0?'stock-out':p.stock<=p.minStock?'stock-low':'stock-ok';
    const margin=p.buyPrice>0?Math.round((p.sellPrice-p.buyPrice)/p.buyPrice*100):0;
    
    // Dual currency calculation
    const cur = p.cur || '₲'; 
    const otherCur = cur === '$' ? '₲' : '$';
    const fxBuy = (FX && FX.buy) ? FX.buy : 7200;
    const fxSell = (FX && FX.sell) ? FX.sell : 7200;
    const rate = cur === '$' ? fxBuy : (1/fxSell);
    
    // Converted values
    const buyConv = cur === '$' ? p.buyPrice * fxBuy : p.buyPrice / fxSell;
    const sellConv = cur === '$' ? p.sellPrice * fxBuy : p.sellPrice / fxSell;

    return `<div class="pcard">
      <div class="pcard-cat">${p.cat} · ${p.sku}</div>
      <div class="pcard-name">${p.name}</div>
      ${p.desc?`<div style="font-size:.68rem;color:var(--m3);margin-top:2px">${p.desc}</div>`:''}
      ${sup?`<div style="font-size:.62rem;color:var(--mu);margin-top:4px;font-family:var(--fm)">📦 ${sup.name}</div>`:''}
      <div class="pcard-prices">
        <div class="pcard-price">
          <div class="pcard-price-l">Compra</div>
          <div class="pcard-price-v">
            <div style="font-weight:600">${fmt(p.buyPrice, cur)}</div>
            <div style="font-size:.6rem;color:var(--mu);margin-top:1px">${fmt(buyConv, otherCur)}</div>
          </div>
        </div>
        <div class="pcard-price">
          <div class="pcard-price-l">Venta</div>
          <div class="pcard-price-v" style="color:var(--g2)">
            <div style="font-weight:600">${fmt(p.sellPrice, cur)}</div>
            <div style="font-size:.6rem;color:var(--mu);margin-top:1px">${fmt(sellConv, otherCur)}</div>
          </div>
        </div>
        <div class="pcard-price"><div class="pcard-price-l">Margen</div><div class="pcard-price-v" style="color:var(--pos)">${margin}%</div></div>
      </div>
      <div class="pcard-stock">
        <div>
          <span class="mono ${stockClass}" style="font-size:.8rem;font-weight:600">${p.stock} u.</span>
          <span style="font-size:.6rem;color:var(--m3);font-family:var(--fm);margin-left:5px">mín: ${p.minStock}</span>
        </div>
        ${p.stock<=0?'<span class="pill pill-neg">Sin stock</span>':p.stock<=p.minStock?'<span class="pill pill-warn">Stock bajo</span>':'<span class="pill pill-pos">En stock</span>'}
      </div>
      <div class="pcard-actions">
        <button class="btn btn-o" onclick="openStockModal('${p.id}')">± Stock</button>
        <button class="btn btn-s" onclick="openProdModal('${p.id}')">✏</button>
        <button class="btn btn-danger" onclick="delProduct('${p.id}')">✕</button>
      </div>
    </div>`;
  }).join('');
}

function openProdModal(id){
  editIds.prod=id||null;
  const p=id?S.products.find(x=>x.id===id):null;
  g('prod-mttl').textContent=id?'Editar producto':'Nuevo producto';
  g('pr-name').value=p?.name||'';g('pr-sku').value=p?.sku||'';g('pr-cat').value=p?.cat||'Relojes';
  g('pr-sup').value=p?.sup||'';g('pr-buy').value=p?.buyPrice||'';g('pr-sell').value=p?.sellPrice||'';
  g('pr-cur').value=p?.cur||'₲';
  g('pr-stock').value=p?.stock??'';g('pr-min').value=p?.minStock??2;g('pr-desc').value=p?.desc||'';
  g('prod-acts').innerHTML=id
    ?`<button class="mb mb-d" onclick="delProduct('${id}');cm('prod-modal')">Eliminar</button><button class="mb mb-gh" onclick="cm('prod-modal')">Cancelar</button><button class="mb mb-g" onclick="saveProd()">Guardar</button>`
    :`<button class="mb mb-gh" onclick="cm('prod-modal')">Cancelar</button><button class="mb mb-g" onclick="saveProd()">Guardar</button>`;
  g('prod-modal').style.display='flex';
}
function saveProd(){
  const name=g('pr-name').value.trim();if(!name){toast('Ingresá un nombre');return}
  const prod={name,sku:g('pr-sku').value.trim(),cat:g('pr-cat').value,sup:g('pr-sup').value,buyPrice:parseFloat(g('pr-buy').value)||0,sellPrice:parseFloat(g('pr-sell').value)||0,cur:g('pr-cur').value,stock:parseInt(g('pr-stock').value)||0,minStock:parseInt(g('pr-min').value)||2,desc:g('pr-desc').value.trim()};
  if(editIds.prod){const i=S.products.findIndex(p=>p.id===editIds.prod);if(i>=0)S.products[i]={...S.products[i],...prod};}
  else S.products.push({...prod,id:uid()});
  lsave();renderAll();cm('prod-modal');toast('◆ Producto guardado');populateSelects();
}
function delProduct(id){if(!confirm('¿Eliminar producto?'))return;S.products=S.products.filter(p=>p.id!==id);lsave();renderAll();toast('Eliminado');populateSelects()}

// STOCK
function openStockModal(pid){
  stockProdId=pid;const p=S.products.find(x=>x.id===pid);
  g('stock-mttl').textContent=`Stock: ${p.name}`;g('stk-qty').value='';g('stk-notes').value='';
  g('stock-modal').style.display='flex';
}
function saveStock(){
  const p=S.products.find(x=>x.id===stockProdId);if(!p)return;
  const qty=parseInt(g('stk-qty').value)||0;const type=g('stk-type').value;const reason=g('stk-reason').value;
  if(qty<=0&&type!=='set'){toast('Ingresá una cantidad');return}
  const prev=p.stock;
  if(type==='in')p.stock+=qty;else if(type==='out'){if(qty>p.stock){toast('No hay suficiente stock');return}p.stock-=qty;}else p.stock=qty;
  const notes=g('stk-notes').value;
  // auto tx if set reason is purchase
  if(reason==='Compra a proveedor'&&type==='in'&&p.buyPrice>0){
    S.txs.push({id:uid(),type:'expense',desc:`Compra stock: ${p.name} (${qty} u.)`,amount:qty*p.buyPrice,cur:'$',cat:'Stock / Compras',date:today()});
  }
  toast(`◆ Stock actualizado: ${prev} → ${p.stock} u.`);
  lsave();renderAll();cm('stock-modal');
}
