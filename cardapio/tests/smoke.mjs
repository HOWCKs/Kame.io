// Smoke test do cardápio: sobe o index.html num DOM simulado (jsdom) e
// percorre o fluxo inteiro — buscar, filtrar, montar, pedir, enviar.
// Rode com `npm test` dentro de cardapio/.
import { JSDOM, VirtualConsole } from 'jsdom';
import fs from 'node:fs';
import { fileURLToPath } from 'node:url';

const indexUrl = new URL('../index.html', import.meta.url);
const indexPath = fileURLToPath(indexUrl);

const errors = [];
const vc = new VirtualConsole();
vc.on('jsdomError', (e) => { const m = String(e.stack || e.message); if (!m.includes('fonts.googleapis.com')) errors.push('jsdomError: ' + m); });
vc.on('error', (...a) => errors.push('console.error: ' + a.join(' ')));
vc.on('warn', () => {});
vc.on('log', () => {});

const html = fs.readFileSync(indexPath, 'utf8');

const dom = new JSDOM(html, {
  url: indexUrl.href,
  runScripts: 'dangerously',
  resources: 'usable',
  pretendToBeVisual: true,
  virtualConsole: vc,
  beforeParse(win) {
    win.IntersectionObserver = class {
      constructor(cb) { this.cb = cb; }
      observe(el) { this.cb([{ isIntersecting: true, target: el }], this); }
      unobserve() {}
      disconnect() {}
    };
    win.matchMedia = win.matchMedia || ((q) => ({
      matches: false, media: q, addListener() {}, removeListener() {},
      addEventListener() {}, removeEventListener() {},
    }));
    win.requestAnimationFrame = (cb) => setTimeout(() => cb(Date.now()), 16);
    win.cancelAnimationFrame = (id) => clearTimeout(id);
    win.open = (url) => { win.__lastUrl = url; return null; };
  },
});

const { window } = dom;
const doc = window.document;
const $ = (s) => doc.querySelector(s);
const $$ = (s) => Array.from(doc.querySelectorAll(s));

const wait = (ms) => new Promise((r) => setTimeout(r, ms));
await new Promise((r) => window.addEventListener('load', r));
await wait(400);

const results = [];
const check = (name, cond, extra = '') => {
  const line = `${cond ? 'PASS' : 'FAIL'}  ${name}${extra ? ' — ' + extra : ''}`; results.push(line); console.log(line);
  return cond;
};

/* 1. boot */
check('scripts carregaram (ClayArt/Morph/ITEMS)', window.eval('typeof ClayArt === "object" && typeof Morph === "object" && Array.isArray(ITEMS)'));
check('grade renderizou 15 itens', $$('#menuGrid .card').length === 15, `${$$('#menuGrid .card').length}`);
check('cada card tem glifo SVG', $$('#menuGrid .card svg').length >= 15);
check('trilha tem 5 categorias', $$('#rail .chip').length === 5);
check('combos renderizaram 3', $$('#comboGrid .combo').length === 3);
check('núcleo morph criou 13 fatias', $$('#morphLayers path').length === 13);
check('face do morph tem path', ($('#morphTop').getAttribute('d') || '').length > 100);
check('marca tem blob desenhado', ($('#brandBlob').getAttribute('d') || '').startsWith('M'));

/* 2. busca */
const search = $('#search');
search.value = 'milkshake';
search.dispatchEvent(new window.Event('input', { bubbles: true }));
await wait(300);
check('busca filtra para 1 item', $$('#menuGrid .card').length === 1, `${$$('#menuGrid .card').length}`);
search.value = 'zzz';
search.dispatchEvent(new window.Event('input', { bubbles: true }));
await wait(300);
check('estado vazio aparece', !$('#emptyState').hidden && $('#menuGrid').hidden);
$('#emptyState [data-reset]').dispatchEvent(new window.MouseEvent('click', { bubbles: true }));
await wait(300);
check('reset devolve 15 itens', $$('#menuGrid .card').length === 15);

/* 3. categoria */
const cat = $$('#rail .chip').find((c) => c.dataset.cat === 'bebidas');
cat.dispatchEvent(new window.MouseEvent('click', { bubbles: true }));
await wait(60);
check('filtro de categoria bebidas = 4', $$('#menuGrid .card').length === 4, `${$$('#menuGrid .card').length}`);
check('aria-selected atualizado', cat.getAttribute('aria-selected') === 'true');
$$('#rail .chip').find((c) => c.dataset.cat === 'all').dispatchEvent(new window.MouseEvent('click', { bubbles: true }));
await wait(60);

/* 4. ordenação */
$$('.sort button').find((b) => b.dataset.sort === 'price').dispatchEvent(new window.MouseEvent('click', { bubbles: true }));
await wait(60);
const prices = $$('#menuGrid .card .price').map((p) => parseFloat(p.textContent.replace('R$', '').replace(',', '.')));
check('ordenação por preço crescente', prices.every((v, i) => i === 0 || prices[i - 1] <= v), prices.slice(0, 4).join(','));

/* 5. adicionar ao carrinho pelo card */
$('#menuGrid [data-add]').dispatchEvent(new window.MouseEvent('click', { bubbles: true }));
await wait(60);
check('contador do carrinho = 1', $('#cartCount').textContent === '1', $('#cartCount').textContent);
check('barra móvel ativou', $('#mobileBar').classList.contains('is-on'));

/* 6. detalhe com opções */
$('#menuGrid [data-open]').dispatchEvent(new window.MouseEvent('click', { bubbles: true }));
await wait(60);
check('folha de detalhe abriu', !$('#itemSheet').hidden);
const opts = $$('#itemSheet .opt');
check('detalhe mostra opções', opts.length >= 3, `${opts.length}`);
const extraOpt = opts.find((o) => o.dataset.choice === 'bacon');
if (extraOpt) {
  extraOpt.dispatchEvent(new window.MouseEvent('click', { bubbles: true }));
  await wait(30);
  check('extra marcado (aria-pressed)', extraOpt.getAttribute('aria-pressed') === 'true');
}
$('#itemSheet [data-qty="1"]').dispatchEvent(new window.MouseEvent('click', { bubbles: true }));
await wait(30);
check('quantidade = 2', $('#detailQty').textContent === '2');
$('#itemSheet [data-confirm]').dispatchEvent(new window.MouseEvent('click', { bubbles: true }));
await wait(400);
check('carrinho soma 3 itens (1 + 2)', $('#cartCount').textContent === '3', $('#cartCount').textContent);

/* 7. gaveta do pedido */
$('#cartOpen').dispatchEvent(new window.MouseEvent('click', { bubbles: true }));
await wait(60);
check('gaveta abriu', !$('#cartDrawer').hidden && $('#cartDrawer').classList.contains('is-open'));
check('gaveta lista 2 linhas', $$('#cartBody .line-item').length === 2, `${$$('#cartBody .line-item').length}`);
const totalBefore = $('#sumTotal').textContent;
check('total preenchido', /R\$/.test(totalBefore), totalBefore);
$('#cartBody [data-inc]').dispatchEvent(new window.MouseEvent('click', { bubbles: true }));
await wait(60);
check('incremento muda total', $('#sumTotal').textContent !== totalBefore);
/* modo entrega */
$('#cartFoot [data-mode="delivery"]').dispatchEvent(new window.MouseEvent('click', { bubbles: true }));
await wait(60);
check('taxa de entrega aparece', $('#sumDelivery').textContent.includes('6,90'), $('#sumDelivery').textContent);

/* 8. remoção */
const kill = $$('#cartBody [data-kill]')[0];
kill.dispatchEvent(new window.MouseEvent('click', { bubbles: true }));
await wait(400);
check('linha removida', $$('#cartBody .line-item').length === 1, `${$$('#cartBody .line-item').length}`);

/* 9. checkout */
$('#checkout').dispatchEvent(new window.MouseEvent('click', { bubbles: true }));
await wait(600);
check('checkout abriu', !$('#orderSheet').hidden);
$('#orderSheet [data-send]').dispatchEvent(new window.MouseEvent('click', { bubbles: true }));
await wait(60);
check('validação bloqueia envio vazio', !!$('#ordNameErr').textContent && !$('#orderSheet .done'));
$('#ordName').value = 'Ana';
$('#ordWhere').value = 'Mesa 4';
$('#orderSheet [data-send]').dispatchEvent(new window.MouseEvent('click', { bubbles: true }));
await wait(120);
check('link do WhatsApp gerado', String(window.__lastUrl || '').startsWith('https://wa.me/5511999999999?text='));
check('mensagem contém o pedido', decodeURIComponent(String(window.__lastUrl || '')).includes('Total'));
check('tela de sucesso', !!$('#orderSheet .done'));
check('carrinho esvaziou', $('#cartCount').textContent === '0', $('#cartCount').textContent);

/* 10. tema */
const before = doc.documentElement.dataset.theme;
$('#themeToggle').dispatchEvent(new window.MouseEvent('click', { bubbles: true }));
await wait(30);
check('tema alterna', doc.documentElement.dataset.theme !== before, `${before} -> ${doc.documentElement.dataset.theme}`);

/* 11. teclado / Esc */
$('#orderSheet [data-close-sheet]').dispatchEvent(new window.MouseEvent('click', { bubbles: true }));
await wait(400);
check('Esc/saída fechou a folha de sucesso', $('#orderSheet').hidden);
$('#cartOpen').dispatchEvent(new window.MouseEvent('click', { bubbles: true }));
await wait(60);
doc.dispatchEvent(new window.KeyboardEvent('keydown', { key: 'Escape', bubbles: true }));
await wait(600);
check('Esc fecha a gaveta', !$('#cartDrawer').classList.contains('is-open'));

/* 12. combos */
$('#comboGrid [data-combo]').dispatchEvent(new window.MouseEvent('click', { bubbles: true }));
await wait(300);
check('combo adiciona 3 itens', $('#cartCount').textContent === '3', $('#cartCount').textContent);

/* 13. acessibilidade básica */
const noAlt = $$('img:not([alt])').length;
check('sem img sem alt', noAlt === 0);
const unlabeled = $$('button:not([aria-label]):not([title])').filter((b) => !b.textContent.trim());
check('todo botão tem rótulo', unlabeled.length === 0, `${unlabeled.length} sem rótulo`);

console.log(results.join('\n'));
console.log('\nerros de runtime:', errors.length);
errors.slice(0, 10).forEach((e) => console.log('  ' + e));
const failed = results.filter((r) => r.startsWith('FAIL')).length;
console.log(`\n${results.length - failed}/${results.length} checks OK`);
process.exit(failed || errors.length ? 1 : 0);
