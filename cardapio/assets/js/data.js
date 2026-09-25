/* ═══════════════════════════════════════════════════════════════════════
   MORPHIS · dados do cardápio
   ───────────────────────────────────────────────────────────────────────
   Este arquivo é a única fonte de conteúdo. Para trocar o cardápio,
   edite apenas ITEMS / COMBOS / STORE — nada de HTML ou CSS.
   Campos de um item:
     id, name, desc, price, cat, glyph, tint, tags[], time (min),
     rating (0-5), orders (popularidade), options[] (grupos de escolha)
   ═══════════════════════════════════════════════════════════════════════ */

const STORE = {
  name: 'MORPHIS',
  whatsapp: '5511999999999',
  deliveryFee: 6.9,
  minPrep: 15,
};

const CATEGORIES = [
  { id: 'all',    label: 'Tudo',       tint: '#FF6A3D', glyph: 'burger' },
  { id: 'lanches',   label: 'Lanches',    tint: '#FF6A3D' },
  { id: 'porcoes',   label: 'Porções',    tint: '#F2A33C' },
  { id: 'bebidas',   label: 'Bebidas',    tint: '#49BDF6' },
  { id: 'sobremesas',label: 'Sobremesas', tint: '#FF6FA5' },
];

const TINTS = {
  lanches: '#FF6A3D',
  porcoes: '#F2A33C',
  bebidas: '#49BDF6',
  sobremesas: '#FF6FA5',
};

/* Grupos de opções reutilizáveis — mantêm preços e rótulos consistentes. */
const OPT = {
  ponto: {
    id: 'ponto', label: 'Ponto da carne', type: 'single',
    choices: [
      { id: 'ao-ponto',   label: 'Ao ponto',      price: 0 },
      { id: 'mal',        label: 'Mal passado',   price: 0 },
      { id: 'bem',        label: 'Bem passado',   price: 0 },
    ],
  },
  tamanho: {
    id: 'tamanho', label: 'Tamanho', type: 'single',
    choices: [
      { id: 'p', label: '300 ml', price: 0 },
      { id: 'm', label: '500 ml', price: 4 },
      { id: 'g', label: '700 ml', price: 7 },
    ],
  },
  extras: {
    id: 'extras', label: 'Adicionar', type: 'multi',
    choices: [
      { id: 'bacon',   label: 'Bacon crocante',   price: 5.5 },
      { id: 'cheddar', label: 'Cheddar extra',    price: 4.0 },
      { id: 'ovo',     label: 'Ovo chapéu',       price: 3.5 },
      { id: 'picles',  label: 'Picles da casa',   price: 2.5 },
    ],
  },
  molhos: {
    id: 'molhos', label: 'Molho da casa', type: 'single',
    choices: [
      { id: 'defumado', label: 'Defumado',      price: 0 },
      { id: 'picante',  label: 'Picante honey', price: 0 },
      { id: 'alho',     label: 'Maionese de alho', price: 0 },
      { id: 'sem',      label: 'Sem molho',     price: 0 },
    ],
  },
  gelo: {
    id: 'gelo', label: 'Serviço', type: 'single',
    choices: [
      { id: 'gelo',   label: 'Com gelo', price: 0 },
      { id: 'sem',    label: 'Sem gelo', price: 0 },
    ],
  },
};

const ITEMS = [
  {
    id: 'smash-morph', name: 'Smash Morph', cat: 'lanches', glyph: 'smash',
    price: 28.9, time: 18, rating: 4.9, orders: 412,
    tags: [{ label: 'Mais pedido', kind: 'hot' }],
    desc: 'Dois discos de fraldinha prensados na chapa, cheddar derretido, picles e maionese da casa no brioche tostado.',
    options: [OPT.ponto, OPT.extras, OPT.molhos],
  },
  {
    id: 'x-clay-duplo', name: 'X-Clay Duplo', cat: 'lanches', glyph: 'burger',
    price: 34.9, time: 22, rating: 4.8, orders: 268,
    tags: [{ label: 'Chef', kind: 'hot' }],
    desc: 'Dois blends de 90 g, bacon crocante, cebola caramelizada por 40 minutos e molho defumado.',
    options: [OPT.ponto, OPT.extras, OPT.molhos],
  },
  {
    id: 'crispy-morph', name: 'Crispy Morph', cat: 'lanches', glyph: 'chicken',
    price: 26.9, time: 20, rating: 4.7, orders: 231,
    tags: [{ label: 'Novo', kind: 'new' }],
    desc: 'Peito de frango marinado 24 h, empanado duas vezes, slaw de repolho e picante honey.',
    options: [OPT.extras, OPT.molhos],
  },
  {
    id: 'veggie-clay', name: 'Veggie Clay', cat: 'lanches', glyph: 'veggie',
    price: 27.9, time: 19, rating: 4.6, orders: 154,
    tags: [{ label: 'Vegetariano', kind: 'veg' }],
    desc: 'Hambúrguer de grão-de-bico e beterraba, queijo minas derretido, rúcula e tomate confit.',
    options: [OPT.extras, OPT.molhos],
  },
  {
    id: 'dog-morph', name: 'Dog Morph', cat: 'lanches', glyph: 'hotdog',
    price: 19.9, time: 14, rating: 4.7, orders: 176,
    tags: [],
    desc: 'Salsicha artesanal grelhada, mostarda e mel, cebola crocante e batata palha no pão de leite.',
    options: [OPT.extras],
  },

  {
    id: 'batata-trufada', name: 'Batata Trufada', cat: 'porcoes', glyph: 'fries',
    price: 24.9, time: 15, rating: 4.8, orders: 305,
    tags: [{ label: 'Mais pedido', kind: 'hot' }],
    desc: 'Batata rústica frita duas vezes, azeite trufado, parmesão e salsinha. Chega crocante, com molho à parte.',
    options: [{ id: 'porcao', label: 'Porção', type: 'single', choices: [
      { id: 'media', label: 'Média (400 g)', price: 0 },
      { id: 'grande', label: 'Grande (700 g)', price: 9 },
    ] }],
  },
  {
    id: 'onion-rings', name: 'Onion Rings', cat: 'porcoes', glyph: 'rings',
    price: 19.9, time: 12, rating: 4.6, orders: 197,
    tags: [],
    desc: 'Anéis de cebola em massa leve de cerveja, fritos na hora, com sal defumado.',
    options: [OPT.molhos],
  },
  {
    id: 'nuggets', name: 'Nuggets Artesanais', cat: 'porcoes', glyph: 'nuggets',
    price: 23.9, time: 16, rating: 4.7, orders: 143,
    tags: [],
    desc: 'Oito unidades de sobrecoxa moída e temperada, empanada em farinha panko. Molho barbecue da casa.',
    options: [OPT.molhos],
  },

  {
    id: 'milkshake', name: 'Milkshake de Baunilha', cat: 'bebidas', glyph: 'shake',
    price: 19.9, time: 8, rating: 4.9, orders: 259,
    tags: [{ label: 'Mais pedido', kind: 'hot' }],
    desc: 'Sorvete de baunilha bourbon batido com leite integral, chantilly e calda de caramelo salgado.',
    options: [OPT.tamanho],
  },
  {
    id: 'refri-artesanal', name: 'Refri Artesanal', cat: 'bebidas', glyph: 'cup',
    price: 10.9, time: 3, rating: 4.5, orders: 388,
    tags: [],
    desc: 'Guaraná, limão ou cola — receita própria, menos açúcar, gaseificação forte.',
    options: [OPT.tamanho, OPT.gelo],
  },
  {
    id: 'limonada', name: 'Limonada Siciliana', cat: 'bebidas', glyph: 'juice',
    price: 13.9, time: 6, rating: 4.8, orders: 164,
    tags: [{ label: 'Novo', kind: 'new' }],
    desc: 'Limão siciliano espremido na hora, toque de gengibre e folhas de hortelã.',
    options: [OPT.tamanho, OPT.gelo],
  },
  {
    id: 'cold-brew', name: 'Cold Brew Tônica', cat: 'bebidas', glyph: 'coffee',
    price: 15.9, time: 5, rating: 4.7, orders: 121,
    tags: [],
    desc: 'Extração lenta de 18 horas, água tônica e casca de laranja. Gelado, seco, direto.',
    options: [OPT.tamanho],
  },

  {
    id: 'brownie', name: 'Brownie Clay', cat: 'sobremesas', glyph: 'brownie',
    price: 17.9, time: 10, rating: 4.8, orders: 187,
    tags: [],
    desc: 'Brownie de chocolate 70% com centro úmido, flor de sal e uma bola de sorvete de creme.',
    options: [{ id: 'acompanha', label: 'Acompanha', type: 'single', choices: [
      { id: 'sorvete', label: 'Sorvete de creme', price: 0 },
      { id: 'calda',   label: 'Calda de chocolate extra', price: 3 },
      { id: 'puro',    label: 'Puro', price: 0 },
    ] }],
  },
  {
    id: 'petit', name: 'Petit Gâteau', cat: 'sobremesas', glyph: 'cake',
    price: 22.9, time: 14, rating: 4.9, orders: 142,
    tags: [{ label: 'Chef', kind: 'hot' }],
    desc: 'Bolo quente de chocolate com coração líquido, assado no momento do pedido.',
    options: [{ id: 'acompanha', label: 'Acompanha', type: 'single', choices: [
      { id: 'sorvete', label: 'Sorvete de baunilha', price: 0 },
      { id: 'doce',    label: 'Doce de leite', price: 0 },
    ] }],
  },
  {
    id: 'acai', name: 'Açaí Morph', cat: 'sobremesas', glyph: 'bowl',
    price: 21.9, time: 7, rating: 4.6, orders: 133,
    tags: [{ label: 'Vegetariano', kind: 'veg' }],
    desc: 'Açaí médio batido com banana, granola de castanhas e mel. Sem xarope, sem corante.',
    options: [{ id: 'tam', label: 'Tamanho', type: 'single', choices: [
      { id: '300', label: '300 ml', price: 0 },
      { id: '500', label: '500 ml', price: 6 },
    ] }],
  },
];

const COMBOS = [
  {
    id: 'combo-morphis', name: 'Combo Morphis', badge: 'Para 1',
    tint: '#FF6A3D', items: ['smash-morph', 'batata-trufada', 'refri-artesanal'],
    price: 49.9,
    pitch: 'O trio que explica a casa: o lanche mais pedido, a batata e um refri.',
  },
  {
    id: 'combo-mesa', name: 'Combo Mesa', badge: 'Para 2',
    tint: '#7A63FF', items: ['x-clay-duplo', 'crispy-morph', 'onion-rings', 'refri-artesanal', 'refri-artesanal'],
    price: 84.9,
    pitch: 'Dois lanches diferentes, porção no meio e bebida para cada um.',
  },
  {
    id: 'combo-doce', name: 'Combo Doce', badge: 'Sobremesa',
    tint: '#FF6FA5', items: ['brownie', 'brownie', 'milkshake', 'milkshake'],
    price: 59.9,
    pitch: 'Para quando a fome já passou e o assunto ainda não terminou.',
  },
];
