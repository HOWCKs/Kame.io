/* ═══════════════════════════════════════════════════════════════════════
   MORPHIS · app.js
   Estado, renderização e interação. Regras do jogo:
     · todo estado vive em `state` e é persistido (carrinho + tema);
     · a renderização é declarativa — o DOM é reconstruído a partir do estado;
     · toda ação importante gera feedback (toast + aria-live).
   ═══════════════════════════════════════════════════════════════════════ */

(() => {
  'use strict';

  const $ = (s, r = document) => r.querySelector(s);
  const $$ = (s, r = document) => Array.from(r.querySelectorAll(s));
  const reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  const LS = { cart: 'morphis.cart.v1', theme: 'morphis.theme.v1' };

  /* ── estado ──────────────────────────────────────────────────────────── */
  const state = {
    cat: 'all',
    query: '',
    sort: 'popular',
    mode: 'pickup',
    cart: load(LS.cart) || [],
    detail: null,   // { item, qty, choices: {groupId: choiceId | [ids]} }
    order: null,    // rascunho do checkout
  };

  function load(key) { try { return JSON.parse(localStorage.getItem(key)); } catch { return null; } }
  function save(key, value) { try { localStorage.setItem(key, JSON.stringify(value)); } catch { /* modo privado */ } }

  /* ── formatação ──────────────────────────────────────────────────────── */
  const brl = (n) => n.toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' });
  const priceParts = (n) => {
    const [i, d] = n.toFixed(2).split('.');
    return `<span class="price">R$ ${i}<small>,${d}</small></span>`;
  };
  const byId = (id) => ITEMS.find((i) => i.id === id);

  /* ── ícones ──────────────────────────────────────────────────────────── */
  const ICON = {
    clock: '<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3.5 2"/></svg>',
    star: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 4l2.4 5 5.6.8-4 4 1 5.6L12 16.8 6.9 19.4l1-5.6-4-4 5.6-.8z"/></svg>',
    plus: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 5v14M5 12h14"/></svg>',
    trash: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 7h14M10 7V5h4v2M7 7l1 12h8l1-12"/></svg>',
    check: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 13l4.5 4.5L19 7"/></svg>',
    close: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M6 6l12 12M18 6L6 18"/></svg>',
    minus: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 12h14"/></svg>',
  };

  /* ── carrinho ────────────────────────────────────────────────────────── */
  function choiceLabel(item, groupId, id) {
    const g = (item.options || []).find((o) => o.id === groupId);
    const c = g && g.choices.find((x) => x.id === id);
    return c ? c.label : null;
  }

  function addToCart(entry) {
    const key = entry.key;
    const found = state.cart.find((l) => l.key === key);
    if (found) found.qty += entry.qty;
    else state.cart.push({ ...entry });
    persist();
    renderCart();
    bumpCart();
    toast(`${entry.qty}× ${entry.name} entrou no pedido`);
    announce(`${entry.name} adicionado. ${cartCount()} item(ns) no pedido, total ${brl(subtotal() + delivery())}.`);
  }

  function cartCount() { return state.cart.reduce((n, l) => n + l.qty, 0); }
  function subtotal() { return state.cart.reduce((n, l) => n + l.unit * l.qty, 0); }
  function delivery() { return state.mode === 'delivery' && state.cart.length ? STORE.deliveryFee : 0; }
  function persist() { save(LS.cart, state.cart); }

  /* ── toasts & acessibilidade ─────────────────────────────────────────── */
  function toast(text, kind) {
    const el = document.createElement('div');
    el.className = `toast${kind === 'warn' ? ' toast--warn' : ''}`;
    el.innerHTML = `${kind === 'warn' ? ICON.close : ICON.check}<span>${text}</span>`;
    $('#toasts').appendChild(el);
    setTimeout(() => {
      el.classList.add('is-out');
      setTimeout(() => el.remove(), 400);
    }, 2600);
  }
  function announce(text) { $('#liveRegion').textContent = text; }

  function bumpCart() {
    const badge = $('#cartCount');
    badge.textContent = String(cartCount());
    badge.dataset.empty = cartCount() === 0 ? 'true' : 'false';
    badge.classList.remove('is-bump');
    void badge.offsetWidth;
    badge.classList.add('is-bump');
  }

  /* ── filtros ─────────────────────────────────────────────────────────── */
  function visibleItems() {
    const q = state.query.trim().toLowerCase();
    let list = ITEMS.filter((i) => state.cat === 'all' || i.cat === state.cat);
    if (q) {
      list = list.filter((i) =>
        i.name.toLowerCase().includes(q) ||
        i.desc.toLowerCase().includes(q) ||
        (i.tags || []).some((t) => t.label.toLowerCase().includes(q)));
    }
    const sorters = {
      popular: (a, b) => b.orders - a.orders,
      price: (a, b) => a.price - b.price,
      time: (a, b) => a.time - b.time,
    };
    return list.sort(sorters[state.sort]);
  }

  /* ── trilha de categorias ────────────────────────────────────────────── */
  function renderRail() {
    const rail = $('#rail');
    rail.innerHTML = CATEGORIES.map((c) => {
      const count = c.id === 'all' ? ITEMS.length : ITEMS.filter((i) => i.cat === c.id).length;
      return `<button class="chip" role="tab" type="button" data-cat="${c.id}" style="--chip:${c.tint}"
        aria-selected="${state.cat === c.id}">${c.label}<span class="chip__count">${count}</span></button>`;
    }).join('');
  }

  /* ── grade do cardápio ───────────────────────────────────────────────── */
  function cardHTML(item) {
    const tint = TINTS[item.cat];
    const tags = (item.tags || []).map((t) => `<span class="tag tag--${t.kind}">${t.label}</span>`).join('');
    return `
      <article class="card" data-id="${item.id}" style="--tint:${tint}">
        <div class="card__art">
          <div class="card__tags">${tags}</div>
          ${ClayArt.glyph(item.glyph)}
        </div>
        <h3 class="card__title"><button type="button" class="card__title-btn" data-open="${item.id}">${item.name}</button></h3>
        <p class="card__desc">${item.desc}</p>
        <div class="card__meta">
          <span>${ICON.clock} ${item.time} min</span>
          <span>${ICON.star} ${item.rating.toFixed(1).replace('.', ',')}</span>
          <span>${item.orders} pedidos</span>
        </div>
        <div class="card__foot">
          ${priceParts(item.price)}
          <button class="add-btn" type="button" data-add="${item.id}"
            aria-label="Adicionar ${item.name} ao pedido">${ICON.plus}</button>
        </div>
      </article>`;
  }

  function renderGrid() {
    const list = visibleItems();
    const grid = $('#menuGrid');
    grid.innerHTML = list.map(cardHTML).join('');
    $('#emptyState').hidden = list.length > 0;
    grid.hidden = list.length === 0;
  }

  /* ── combos ──────────────────────────────────────────────────────────── */
  function renderCombos() {
    $('#comboGrid').innerHTML = COMBOS.map((c) => {
      const from = c.items.reduce((n, id) => n + (byId(id) ? byId(id).price : 0), 0);
      const off = Math.round(((from - c.price) / from) * 100);
      const names = [...new Set(c.items)].map((id) => byId(id).name).join(' + ');
      return `
        <article class="combo" style="--tint:${c.tint}">
          <span class="combo__badge">${c.badge}</span>
          <h3>${c.name}</h3>
          <p class="combo__items">${names}</p>
          <p>${c.pitch}</p>
          <div class="combo__price">
            <strong>${brl(c.price)}</strong>
            <s>${brl(from)}</s>
            <span class="combo__save">−${off}%</span>
          </div>
          <button class="btn" type="button" data-combo="${c.id}">Adicionar combo</button>
        </article>`;
    }).join('');
  }

  /* ── gaveta do pedido ────────────────────────────────────────────────── */
  function renderCart() {
    const body = $('#cartBody');
    const foot = $('#cartFoot');

    if (!state.cart.length) {
      body.innerHTML = `
        <div class="empty-cart">
          <svg viewBox="-70 -70 140 140" aria-hidden="true"><path id="cartEmptyBlob" fill="var(--paper-3)"/></svg>
          <h3>Seu pedido ainda é matéria-prima</h3>
          <p>Escolha um lanche e ele aparece aqui, moldado do seu jeito. Nada é cobrado nesta tela.</p>
          <button class="btn btn--ghost glass" type="button" data-close-cart>Ver cardápio</button>
        </div>`;
      Morph.deflatedBlob($('#cartEmptyBlob'));
      foot.hidden = true;
      $('#cartSub').textContent = 'Matéria-prima escolhida, nada cozido ainda.';
    } else {
      body.innerHTML = state.cart.map((l) => {
        const item = byId(l.itemId);
        return `
          <div class="line-item" style="--tint:${TINTS[item.cat]}" data-key="${l.key}">
            <div class="line-item__art">${ClayArt.glyph(item.glyph, 60)}</div>
            <div>
              <p class="line-item__name">${l.name}</p>
              ${l.extras.length ? `<p class="line-item__extras">${l.extras.join(' · ')}</p>` : ''}
              <div class="line-item__ctl">
                <div class="stepper">
                  <button type="button" data-dec="${l.key}" aria-label="Menos ${l.name}">−</button>
                  <span>${l.qty}</span>
                  <button type="button" data-inc="${l.key}" aria-label="Mais ${l.name}">+</button>
                </div>
                <button class="line-item__kill" type="button" data-kill="${l.key}" aria-label="Remover ${l.name}">${ICON.trash}</button>
              </div>
            </div>
            <p class="line-item__price">${brl(l.unit * l.qty)}</p>
          </div>`;
      }).join('');
      foot.hidden = false;
      $('#cartSub').textContent = `${cartCount()} ${cartCount() === 1 ? 'item' : 'itens'} · preparo estimado ${estimate()} min`;
    }

    $('#sumSubtotal').textContent = brl(subtotal());
    $('#sumDelivery').textContent = state.mode === 'delivery' ? brl(STORE.deliveryFee) : 'Grátis';
    $('#sumTotal').textContent = brl(subtotal() + delivery());

    const bar = $('#mobileBar');
    bar.classList.toggle('is-on', state.cart.length > 0);
    $('#mobileCount').textContent = `${cartCount()} ${cartCount() === 1 ? 'item' : 'itens'}`;
    $('#mobileTotal').textContent = brl(subtotal() + delivery());
  }

  function estimate() {
    if (!state.cart.length) return 0;
    const max = Math.max(...state.cart.map((l) => byId(l.itemId).time));
    return max + (state.mode === 'delivery' ? 15 : 0);
  }

  /* ── folha de detalhe ────────────────────────────────────────────────── */
  function openDetail(id) {
    const item = byId(id);
    if (!item) return;
    const choices = {};
    (item.options || []).forEach((g) => { choices[g.id] = g.type === 'single' ? g.choices[0].id : []; });
    state.detail = { item, qty: 1, choices };

    const sheet = $('.sheet', $('#itemSheet'));
    sheet.innerHTML = `
      <button class="icon-btn glass sheet__close" type="button" data-close-sheet aria-label="Fechar detalhe">${ICON.close}</button>
      <div class="detail">
        <div class="detail__art">${ClayArt.glyph(item.glyph, 240)}</div>
        <h2 id="sheetTitle">${item.name}</h2>
        <p class="detail__desc">${item.desc}</p>
        <div class="detail__meta">
          <span>${ICON.clock} ${item.time} min</span>
          <span>${ICON.star} ${item.rating.toFixed(1).replace('.', ',')} · ${item.orders} pedidos</span>
        </div>
        ${(item.options || []).map(optGroupHTML).join('')}
        <div class="detail__foot">
          <div class="detail__qty">
            <button type="button" data-qty="-1" aria-label="Diminuir quantidade">−</button>
            <span id="detailQty">1</span>
            <button type="button" data-qty="1" aria-label="Aumentar quantidade">+</button>
          </div>
          <button class="btn btn--primary clay btn--block" type="button" data-confirm>
            Adicionar <span id="detailTotal">${brl(item.price)}</span>
          </button>
        </div>
      </div>`;
    openSheet($('#itemSheet'), $('.sheet__close', sheet));
  }

  function optGroupHTML(group) {
    const d = state.detail;
    return `
      <div class="opt-group">
        <h3>${group.label}</h3>
        <div class="opts">
          ${group.choices.map((c) => {
            const on = group.type === 'single'
              ? d.choices[group.id] === c.id
              : d.choices[group.id].includes(c.id);
            return `<button class="opt" type="button" aria-pressed="${on}" role="${group.type === 'single' ? 'radio' : 'checkbox'}"
              data-group="${group.id}" data-choice="${c.id}">
              <span>${c.label}</span>
              <span class="opt__price">${c.price ? `+ ${brl(c.price)}` : ''}</span>
              <span class="opt__check" aria-hidden="true"></span>
            </button>`;
          }).join('')}
        </div>
      </div>`;
  }

  function detailUnit() {
    const { item, choices } = state.detail;
    let total = item.price;
    (item.options || []).forEach((g) => {
      const sel = choices[g.id];
      const ids = Array.isArray(sel) ? sel : [sel];
      ids.forEach((id) => {
        const c = g.choices.find((x) => x.id === id);
        if (c) total += c.price;
      });
    });
    return total;
  }

  function refreshDetail() {
    const d = state.detail;
    if (!d) return;
    $('#detailQty').textContent = String(d.qty);
    const totalEl = $('#detailTotal');
    if (totalEl) totalEl.textContent = brl(detailUnit() * d.qty);
    $$('#itemSheet .opt').forEach((btn) => {
      const g = (d.item.options || []).find((x) => x.id === btn.dataset.group);
      const sel = d.choices[g.id];
      const on = Array.isArray(sel) ? sel.includes(btn.dataset.choice) : sel === btn.dataset.choice;
      btn.setAttribute('aria-pressed', String(on));
    });
  }

  function confirmDetail() {
    const { item, qty, choices } = state.detail;
    const extras = [];
    let unit = item.price;
    (item.options || []).forEach((g) => {
      const sel = choices[g.id];
      const ids = Array.isArray(sel) ? sel : [sel];
      ids.forEach((id) => {
        const c = g.choices.find((x) => x.id === id);
        if (!c) return;
        unit += c.price;
        const label = choiceLabel(item, g.id, id);
        if (label && g.type === 'multi') extras.push(label);
        else if (label && c.price > 0) extras.push(label);
      });
      // escolhas simples sem custo (ponto, molho) entram como detalhe
      if (g.type === 'single') {
        const c = g.choices.find((x) => x.id === sel);
        if (c && !c.price) extras.push(c.label);
      }
    });
    addToCart({
      key: `${item.id}|${extras.sort().join(',')}`,
      itemId: item.id, name: item.name, unit, qty, extras,
    });
    closeSheet($('#itemSheet'));
  }

  /* ── checkout ────────────────────────────────────────────────────────── */
  function openOrder() {
    if (!state.cart.length) { toast('Seu pedido está vazio', 'warn'); return; }
    state.order = { name: '', where: '', pay: 'Pix', note: '' };
    const sheet = $('.sheet', $('#orderSheet'));
    sheet.innerHTML = `
      <button class="icon-btn glass sheet__close" type="button" data-close-sheet aria-label="Fechar checkout">${ICON.close}</button>
      <div class="detail">
        <h2 id="orderTitle">Revisar e enviar</h2>
        <p class="detail__desc">Você confere tudo aqui. No fim, abrimos o WhatsApp com o pedido escrito — nada é pago nesta tela.</p>
        <div class="review">
          ${state.cart.map((l) => `<div><span>${l.qty}× ${l.name}</span><span>${brl(l.unit * l.qty)}</span></div>`).join('')}
          <div><span>Subtotal</span><span>${brl(subtotal())}</span></div>
          <div><span>${state.mode === 'delivery' ? 'Entrega' : 'Retirada'}</span><span>${state.mode === 'delivery' ? brl(STORE.deliveryFee) : 'Grátis'}</span></div>
          <div><strong>Total</strong><strong>${brl(subtotal() + delivery())}</strong></div>
        </div>
        <div class="field">
          <label for="ordName">Seu nome</label>
          <input id="ordName" type="text" autocomplete="name" placeholder="Como chamamos você?" />
          <p class="field__error" id="ordNameErr" aria-live="polite"></p>
        </div>
        <div class="field">
          <label for="ordWhere">${state.mode === 'delivery' ? 'Endereço de entrega' : 'Mesa ou retirada'}</label>
          <input id="ordWhere" type="text" placeholder="${state.mode === 'delivery' ? 'Rua, número, complemento' : 'Ex.: mesa 4 ou balcão'}" />
          <p class="field__error" id="ordWhereErr" aria-live="polite"></p>
        </div>
        <div class="field">
          <label for="ordPay">Pagamento</label>
          <input id="ordPay" type="text" value="Pix" />
        </div>
        <div class="field">
          <label for="ordNote">Observação</label>
          <textarea id="ordNote" rows="2" placeholder="Sem cebola, troco para 50, ponto do lanche…"></textarea>
        </div>
        <div class="detail__foot">
          <button class="btn btn--ghost glass" type="button" data-close-sheet>Voltar ao pedido</button>
          <button class="btn btn--primary clay" type="button" data-send>Enviar no WhatsApp</button>
        </div>
      </div>`;
    openSheet($('#orderSheet'), $('.sheet__close', sheet));
  }

  function orderText() {
    const lines = state.cart.map((l) => `• ${l.qty}× ${l.name}${l.extras.length ? ` (${l.extras.join(', ')})` : ''} — ${brl(l.unit * l.qty)}`);
    return [
      `*Pedido ${STORE.name}*`,
      '',
      ...lines,
      '',
      `Subtotal: ${brl(subtotal())}`,
      `${state.mode === 'delivery' ? 'Entrega' : 'Retirada'}: ${state.mode === 'delivery' ? brl(STORE.deliveryFee) : 'Grátis'}`,
      `*Total: ${brl(subtotal() + delivery())}*`,
      `Preparo estimado: ${estimate()} min`,
      '',
      `Nome: ${state.order.name}`,
      `${state.mode === 'delivery' ? 'Endereço' : 'Retirada'}: ${state.order.where}`,
      `Pagamento: ${state.order.pay}`,
      state.order.note ? `Observação: ${state.order.note}` : '',
    ].filter(Boolean).join('\n');
  }

  function sendOrder() {
    const name = $('#ordName'), where = $('#ordWhere');
    const errN = $('#ordNameErr'), errW = $('#ordWhereErr');
    errN.textContent = ''; errW.textContent = '';
    let bad = false;
    if (name.value.trim().length < 2) { errN.textContent = 'Precisamos de um nome para chamar.'; bad = true; }
    if (where.value.trim().length < 3) { errW.textContent = state.mode === 'delivery' ? 'Informe o endereço de entrega.' : 'Diga a mesa ou “balcão”.'; bad = true; }
    if (bad) { (bad && name.value.trim().length < 2 ? name : where).focus(); toast('Faltam dados para fechar o pedido', 'warn'); return; }

    state.order.name = name.value.trim();
    state.order.where = where.value.trim();
    state.order.pay = $('#ordPay').value.trim() || 'Pix';
    state.order.note = $('#ordNote').value.trim();

    const url = `https://wa.me/${STORE.whatsapp}?text=${encodeURIComponent(orderText())}`;
    window.open(url, '_blank', 'noopener');

    const sheet = $('.sheet', $('#orderSheet'));
    sheet.innerHTML = `
      <div class="done">
        <svg viewBox="0 0 120 120" aria-hidden="true" style="stroke:none">
          <circle cx="60" cy="60" r="46" fill="url(#doneGrad)"/>
          <defs><radialGradient id="doneGrad" cx="34%" cy="26%" r="86%">
            <stop offset="0" stop-color="#8FF0CE"/><stop offset=".55" stop-color="#23C79B"/><stop offset="1" stop-color="#0C7A5C"/>
          </radialGradient></defs>
          <path d="M40 62 l14 14 l28 -32" fill="none" stroke="#FFF9F0" stroke-width="9"
            stroke-linecap="round" stroke-linejoin="round" stroke-dasharray="80" stroke-dashoffset="80">
            <animate attributeName="stroke-dashoffset" from="80" to="0" dur="0.6s" begin="0.15s" fill="freeze" calcMode="spline" keySplines="0.22 1 0.36 1"/>
          </path>
        </svg>
        <h2 id="orderTitle">Pedido escrito</h2>
        <p>Abrimos o WhatsApp com tudo preenchido. Confira e envie — a cozinha começa quando a mensagem chega.</p>
        <p><strong>${brl(subtotal() + delivery())}</strong> · ${estimate()} min de preparo</p>
        <button class="btn btn--primary clay" type="button" data-close-sheet>Fechar</button>
      </div>`;
    state.cart = [];
    persist();
    renderCart();
    bumpCart();
    announce('Pedido enviado para o WhatsApp. Carrinho esvaziado.');
  }

  /* ── folhas & gaveta: abertura, foco, Esc ────────────────────────────── */
  let lastFocus = null;

  function openSheet(wrap, focusEl) {
    lastFocus = document.activeElement;
    wrap.hidden = false;
    requestAnimationFrame(() => wrap.classList.add('is-open'));
    document.body.classList.add('is-locked');
    (focusEl || $('.sheet', wrap)).focus?.();
  }
  function closeSheet(wrap) {
    wrap.classList.remove('is-open');
    document.body.classList.remove('is-locked');
    setTimeout(() => { wrap.hidden = true; }, reduced ? 0 : 320);
    state.detail = null;
    if (lastFocus && document.contains(lastFocus)) lastFocus.focus();
  }
  function openCart() {
    lastFocus = document.activeElement;
    renderCart();
    const d = $('#cartDrawer');
    d.hidden = false;
    requestAnimationFrame(() => d.classList.add('is-open'));
    document.body.classList.add('is-locked');
    $('#cartOpen').setAttribute('aria-expanded', 'true');
    $('#cartClose').focus();
  }
  function closeCart() {
    const d = $('#cartDrawer');
    d.classList.remove('is-open');
    document.body.classList.remove('is-locked');
    $('#cartOpen').setAttribute('aria-expanded', 'false');
    setTimeout(() => { d.hidden = true; }, reduced ? 0 : 420);
    if (lastFocus && document.contains(lastFocus)) lastFocus.focus();
  }
  const anyOpen = () => $('.sheet-wrap.is-open') || $('#cartDrawer.is-open');

  /* ── eventos ─────────────────────────────────────────────────────────── */
  function bind() {
    // categorias
    $('#rail').addEventListener('click', (e) => {
      const chip = e.target.closest('[data-cat]');
      if (!chip) return;
      state.cat = chip.dataset.cat;
      $$('#rail .chip').forEach((c) => c.setAttribute('aria-selected', String(c === chip)));
      renderGrid();
      const tint = (CATEGORIES.find((c) => c.id === state.cat) || {}).tint;
      if (tint && window.hero) window.hero.setColor(tint);
      announce(`Categoria ${chip.textContent.trim()} — ${visibleItems().length} itens.`);
    });

    // ordenação
    $$('.sort button').forEach((b) => b.addEventListener('click', () => {
      state.sort = b.dataset.sort;
      $$('.sort button').forEach((x) => x.classList.toggle('is-on', x === b));
      renderGrid();
    }));

    // busca
    let tId;
    $('#search').addEventListener('input', (e) => {
      clearTimeout(tId);
      tId = setTimeout(() => { state.query = e.target.value; renderGrid(); }, 140);
    });

    // grade: abrir detalhe / adicionar
    $('#menuGrid').addEventListener('click', (e) => {
      const add = e.target.closest('[data-add]');
      if (add) {
        const item = byId(add.dataset.add);
        add.classList.add('is-flying');
        setTimeout(() => add.classList.remove('is-flying'), 520);
        addToCart({ key: `${item.id}|`, itemId: item.id, name: item.name, unit: item.price, qty: 1, extras: [] });
        return;
      }
      const open = e.target.closest('[data-open]');
      if (open) { openDetail(open.dataset.open); return; }
      const card = e.target.closest('.card');
      if (card && !e.target.closest('button')) openDetail(card.dataset.id);
    });

    // combos
    $('#comboGrid').addEventListener('click', (e) => {
      const btn = e.target.closest('[data-combo]');
      if (!btn) return;
      const combo = COMBOS.find((c) => c.id === btn.dataset.combo);
      combo.items.forEach((id) => {
        const item = byId(id);
        if (item) addToCart({ key: `${item.id}|`, itemId: item.id, name: item.name, unit: item.price, qty: 1, extras: [] });
      });
      toast(`Combo ${combo.name} adicionado`);
      openCart();
    });

    // detalhe: opções, quantidade, confirmação
    $('#itemSheet').addEventListener('click', (e) => {
      if (e.target.closest('[data-close-sheet]')) { closeSheet($('#itemSheet')); return; }
      const opt = e.target.closest('.opt');
      if (opt && state.detail) {
        const g = (state.detail.item.options || []).find((x) => x.id === opt.dataset.group);
        const id = opt.dataset.choice;
        if (g.type === 'single') state.detail.choices[g.id] = id;
        else {
          const arr = state.detail.choices[g.id];
          const i = arr.indexOf(id);
          if (i >= 0) arr.splice(i, 1); else arr.push(id);
        }
        refreshDetail();
        return;
      }
      const qty = e.target.closest('[data-qty]');
      if (qty && state.detail) {
        state.detail.qty = Math.max(1, state.detail.qty + Number(qty.dataset.qty));
        refreshDetail();
        return;
      }
      if (e.target.closest('[data-confirm]')) confirmDetail();
    });

    // checkout
    $('#orderSheet').addEventListener('click', (e) => {
      if (e.target.closest('[data-close-sheet]')) { closeSheet($('#orderSheet')); return; }
      if (e.target.closest('[data-send]')) sendOrder();
    });

    // carrinho
    $('#cartOpen').addEventListener('click', openCart);
    $('#mobileCartOpen').addEventListener('click', openCart);
    $('#cartClose').addEventListener('click', closeCart);
    $('#checkout').addEventListener('click', () => { closeCart(); setTimeout(openOrder, reduced ? 0 : 260); });

    $('#cartBody').addEventListener('click', (e) => {
      if (e.target.closest('[data-close-cart]')) { closeCart(); return; }
      const inc = e.target.closest('[data-inc]');
      const dec = e.target.closest('[data-dec]');
      const kill = e.target.closest('[data-kill]');
      const key = (inc || dec || kill) && (inc || dec || kill).dataset;
      if (inc) { const l = state.cart.find((x) => x.key === inc.dataset.inc); if (l) l.qty++; }
      else if (dec) {
        const l = state.cart.find((x) => x.key === dec.dataset.dec);
        if (l) { l.qty--; if (l.qty <= 0) return removeLine(l, dec); }
      } else if (kill) {
        const l = state.cart.find((x) => x.key === kill.dataset.kill);
        if (l) return removeLine(l, kill);
      } else return;
      persist(); renderCart(); bumpCart();
      announce(`Pedido atualizado: ${cartCount()} itens, total ${brl(subtotal() + delivery())}.`);
    });

    // modo de entrega
    $('#cartFoot').addEventListener('click', (e) => {
      const b = e.target.closest('[data-mode]');
      if (!b) return;
      state.mode = b.dataset.mode;
      $$('#cartFoot .mode button').forEach((x) => {
        const on = x === b;
        x.classList.toggle('is-on', on);
        x.setAttribute('aria-checked', String(on));
      });
      renderCart();
      announce(state.mode === 'delivery' ? 'Entrega selecionada, taxa de R$ 6,90.' : 'Retirada selecionada, sem taxa.');
    });

    // tema
    $('#themeToggle').addEventListener('click', () => {
      const night = document.documentElement.dataset.theme === 'night';
      setTheme(night ? 'day' : 'night');
    });

    // teclado
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') {
        if ($('.sheet-wrap.is-open')) closeSheet($('.sheet-wrap.is-open'));
        else if ($('#cartDrawer').classList.contains('is-open')) closeCart();
      }
      if (e.key === '/' && document.activeElement.tagName !== 'INPUT' && document.activeElement.tagName !== 'TEXTAREA') {
        e.preventDefault(); $('#search').focus();
      }
      // foco preso no diálogo aberto
      if (e.key === 'Tab' && anyOpen()) {
        const wrap = $('.sheet-wrap.is-open') || $('#cartDrawer');
        const items = $$('button, input, textarea, [tabindex]:not([tabindex="-1"])', wrap).filter((el) => el.offsetParent);
        if (!items.length) return;
        const first = items[0], last = items[items.length - 1];
        if (e.shiftKey && document.activeElement === first) { e.preventDefault(); last.focus(); }
        else if (!e.shiftKey && document.activeElement === last) { e.preventDefault(); first.focus(); }
      }
    });

    // clique fora fecha as folhas
    $$('.sheet-scrim').forEach((s) => s.addEventListener('click', () => closeSheet(s.parentElement)));

    // estado vazio
    $('#emptyState').addEventListener('click', (e) => {
      if (!e.target.closest('[data-reset]')) return;
      state.query = ''; state.cat = 'all';
      $('#search').value = '';
      renderRail(); renderGrid();
    });

    // cabeçalho fixo + seção ativa
    const header = $('.site-header');
    const onScroll = () => header.classList.toggle('is-stuck', window.scrollY > 8);
    window.addEventListener('scroll', onScroll, { passive: true });
    onScroll();

    const navLinks = $$('.nav a');
    if ('IntersectionObserver' in window) {
      const io = new IntersectionObserver((entries) => {
        entries.forEach((en) => {
          if (!en.isIntersecting) return;
          navLinks.forEach((a) => a.classList.toggle('is-active', a.getAttribute('href') === `#${en.target.id}`));
        });
      }, { rootMargin: '-45% 0px -50% 0px' });
      ['cardapio', 'combos', 'sobre'].forEach((id) => { const el = document.getElementById(id); if (el) io.observe(el); });
    }
  }

  function removeLine(line, el) {
    const row = el.closest('.line-item');
    row.classList.add('is-out');
    announce(`${line.name} removido do pedido.`);
    setTimeout(() => {
      state.cart = state.cart.filter((x) => x.key !== line.key);
      persist(); renderCart(); bumpCart();
    }, reduced ? 0 : 260);
  }

  /* ── tema ────────────────────────────────────────────────────────────── */
  function setTheme(mode) {
    document.documentElement.dataset.theme = mode;
    $('#themeToggle').setAttribute('aria-pressed', String(mode === 'night'));
    $('#themeToggle').setAttribute('aria-label', mode === 'night' ? 'Usar tema claro' : 'Usar tema escuro');
    document.querySelector('meta[name="theme-color"]')?.setAttribute('content', mode === 'night' ? '#100C14' : '#F7F1EA');
    save(LS.theme, mode);
  }

  /* ── revelação ───────────────────────────────────────────────────────── */
  function revealOnScroll() {
    const items = $$('.reveal');
    if (reduced || !('IntersectionObserver' in window)) { items.forEach((i) => i.classList.add('is-in')); return; }
    const io = new IntersectionObserver((entries) => {
      entries.forEach((en, i) => {
        if (!en.isIntersecting) return;
        setTimeout(() => en.target.classList.add('is-in'), i * 60);
        io.unobserve(en.target);
      });
    }, { threshold: 0.12, rootMargin: '0px 0px -8% 0px' });
    items.forEach((i) => io.observe(i));
  }

  /* ── início ──────────────────────────────────────────────────────────── */
  function init() {
    const savedTheme = load(LS.theme);
    setTheme(savedTheme || (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'night' : 'day'));

    renderRail();
    renderGrid();
    renderCombos();
    renderCart();
    bumpCart();
    bind();
    revealOnScroll();

    // núcleo CLAY MORPHIST
    window.hero = new Morph.MorphEngine({
      stage: $('#stage3d'),
      layers: $('#morphLayers'),
      face: $('#morphTop'),
      gloss: $('#morphGloss'),
      shadow: $('#stageShadow'),
      color: TINTS.lanches,
    });
    Morph.staticBlob($('#brandBlob'), { wobble: 0.10, seed: 1.2 });
    $('#brandBlob').setAttribute('transform', 'translate(24 24) scale(0.44)');
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
  else init();
})();
