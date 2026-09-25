/* ═══════════════════════════════════════════════════════════════════════
   MORPHIS · clay-glyphs.js
   Ilustrações em "argila" desenhadas em SVG — nenhuma imagem externa.
   Cada glifo é uma composição de sólidos macios: gradiente radial com luz
   no alto à esquerda, sombra projetada colorida e brilho difuso.
   ═══════════════════════════════════════════════════════════════════════ */

const ClayArt = (() => {
  let seq = 0;
  const uid = (p) => `${p}${(seq++).toString(36)}`;

  /* ── cor ─────────────────────────────────────────────────────────────── */
  const toRgb = (h) => {
    const s = h.replace('#', '');
    const f = s.length === 3 ? s.split('').map((c) => c + c) : [s.slice(0, 2), s.slice(2, 4), s.slice(4, 6)];
    return f.map((v) => parseInt(v, 16));
  };
  const toHex = (a) => '#' + a.map((v) => Math.max(0, Math.min(255, Math.round(v))).toString(16).padStart(2, '0')).join('');
  const mix = (a, b, t) => {
    const x = toRgb(a), y = toRgb(b);
    return toHex(x.map((v, i) => v + (y[i] - v) * t));
  };
  const up = (c, t = 0.2) => mix(c, '#FFFFFF', t);
  const dn = (c, t = 0.2) => mix(c, '#2A1608', t);

  /* ── pedaços de argila ───────────────────────────────────────────────── */
  const grad = (id, c) => `
    <radialGradient id="${id}" cx="33%" cy="22%" r="88%">
      <stop offset="0" stop-color="${up(c, 0.42)}"/>
      <stop offset=".52" stop-color="${c}"/>
      <stop offset="1" stop-color="${dn(c, 0.30)}"/>
    </radialGradient>`;

  const defs = (u, tones) => `
    <defs>
      ${tones.map((c, i) => grad(`${u}g${i}`, c)).join('')}
      <filter id="${u}sh" x="-45%" y="-45%" width="190%" height="200%">
        <feDropShadow dx="0" dy="7" stdDeviation="5.5" flood-color="#4A2410" flood-opacity=".30"/>
      </filter>
      <filter id="${u}bl" x="-60%" y="-60%" width="220%" height="220%">
        <feGaussianBlur stdDeviation="4.5"/>
      </filter>
    </defs>`;

  const g = (i) => `url(#${i})`;
  const gloss = (u, cx, cy, rx, ry, op = 0.5) =>
    `<ellipse cx="${cx}" cy="${cy}" rx="${rx}" ry="${ry}" fill="#FFF6EA" opacity="${op}" filter="url(#${u}bl)"/>`;

  /* ── formas base ─────────────────────────────────────────────────────── */
  const dome = (x, y, w, h) =>
    `M${x} ${y + h} C${x} ${y + h * 0.18} ${x + w * 0.18} ${y} ${x + w / 2} ${y}
     C${x + w * 0.82} ${y} ${x + w} ${y + h * 0.18} ${x + w} ${y + h}
     C${x + w} ${y + h + 6} ${x} ${y + h + 6} ${x} ${y + h} Z`;

  const slab = (x, y, w, h, r) =>
    `M${x + r} ${y} H${x + w - r} A${r} ${r} 0 0 1 ${x + w} ${y + r}
     V${y + h - r} A${r} ${r} 0 0 1 ${x + w - r} ${y + h}
     H${x + r} A${r} ${r} 0 0 1 ${x} ${y + h - r}
     V${y + r} A${r} ${r} 0 0 1 ${x + r} ${y} Z`;

  const tub = (x, y, w, h, r) =>
    `M${x} ${y} H${x + w} L${x + w - 8} ${y + h} A${r} ${r} 0 0 1 ${x + w - 8 - r} ${y + h + r}
     H${x + 8 + r} A${r} ${r} 0 0 1 ${x + 8} ${y + h} Z`;

  const wave = (x, y, w, amp) => {
    const step = w / 4;
    let d = `M${x} ${y}`;
    for (let i = 0; i < 4; i++) d += ` q${step / 2} ${i % 2 ? amp : -amp} ${step} 0`;
    return d;
  };

  /* ── paletas de comida ───────────────────────────────────────────────── */
  const P = {
    bun:     '#EEA84B',
    bunDeep: '#C87A22',
    meat:    '#8A4A28',
    chicken: '#E0A34E',
    cheese:  '#FFC63D',
    green:   '#6FC65F',
    tomato:  '#E8513C',
    cream:   '#FFF3E2',
    onion:   '#C7D96F',
    potato:  '#F5C14E',
    sauza:   '#FF6A3D',
    grape:   '#7B4CA8',
    choco:   '#6B3F24',
    ice:     '#EAF6FF',
  };

  /* ── glifos ──────────────────────────────────────────────────────────── */
  const GLYPHS = {
    /* hambúrguer clássico */
    burger(u) {
      const t = [P.bun, P.green, P.cheese, P.meat, P.bunDeep];
      return `${defs(u, t)}
        <g filter="url(#${u}sh)">
          <path d="${dome(32, 26, 96, 34)}" fill="${g(`${u}g0`)}"/>
          ${[52, 78, 104].map((x, i) => `<ellipse cx="${x}" cy="${34 + (i === 1 ? -2 : 2)}" rx="5" ry="3"
              transform="rotate(${i === 1 ? -12 : 14} ${x} ${34 + (i === 1 ? -2 : 2)})" fill="${up(P.cream, 0.15)}" opacity=".92"/>`).join('')}
          <path d="${wave(28, 66, 104, 9)} v9 q-13 9 -26 0 t-26 0 t-26 0 t-26 0 z" fill="${g(`${u}g1`)}"/>
          <path d="M36 82 H124 L118 96 Q80 106 42 96 Z" fill="${g(`${u}g2`)}"/>
          <path d="${slab(34, 84, 92, 15, 7)}" fill="${g(`${u}g3`)}"/>
          <path d="M34 96 H126 C126 108 106 114 80 114 C54 114 34 108 34 96 Z" fill="${g(`${u}g4`)}"/>
        </g>
        ${gloss(u, 56, 42, 22, 12, 0.5)}`;
    },

    /* smash duplo */
    smash(u) {
      const t = [P.bun, P.cheese, P.meat, P.bunDeep, P.onion];
      return `${defs(u, t)}
        <g filter="url(#${u}sh)">
          <path d="${dome(30, 22, 100, 32)}" fill="${g(`${u}g0`)}"/>
          ${[50, 80, 110].map((x, i) => `<ellipse cx="${x}" cy="${32 + (i === 1 ? -3 : 1)}" rx="5" ry="2.6"
              transform="rotate(${i === 1 ? -10 : 12} ${x} ${32})" fill="${up(P.cream, 0.1)}" opacity=".9"/>`).join('')}
          <path d="M32 56 H128 C130 66 124 70 118 70 H42 C36 70 30 66 32 56 Z" fill="${g(`${u}g1`)}"/>
          <path d="${slab(32, 62, 96, 13, 6)}" fill="${g(`${u}g2`)}"/>
          <path d="M34 76 H126 C128 86 122 90 116 90 H44 C38 90 32 86 34 76 Z" fill="${g(`${u}g1`)}"/>
          <path d="${slab(34, 82, 92, 13, 6)}" fill="${g(`${u}g2`)}"/>
          <path d="M36 94 H124 C124 106 104 113 80 113 C56 113 36 106 36 94 Z" fill="${g(`${u}g3`)}"/>
          <path d="${wave(38, 78, 84, 5)}" fill="none" stroke="${g(`${u}g4`)}" stroke-width="4" style="stroke-linejoin:round"/>
        </g>
        ${gloss(u, 54, 38, 20, 11, 0.5)}`;
    },

    /* frango crocante */
    chicken(u) {
      const t = [P.bun, P.chicken, P.green, P.cheese, P.bunDeep];
      return `${defs(u, t)}
        <g filter="url(#${u}sh)">
          <path d="${dome(32, 24, 96, 33)}" fill="${g(`${u}g0`)}"/>
          <ellipse cx="58" cy="36" rx="5" ry="3" fill="${up(P.cream, 0.1)}" opacity=".9"/>
          <ellipse cx="98" cy="33" rx="5" ry="3" fill="${up(P.cream, 0.1)}" opacity=".9"/>
          <path d="M36 62 C50 54 62 70 76 62 C90 54 104 70 120 62 L120 74 C104 82 90 66 76 74 C62 82 50 66 36 74 Z" fill="${g(`${u}g1`)}"/>
          <path d="${wave(30, 78, 100, 8)} v8 q-12 8 -25 0 t-25 0 t-25 0 t-25 0 z" fill="${g(`${u}g2`)}"/>
          <path d="M38 92 H122 L116 102 Q80 110 44 102 Z" fill="${g(`${u}g3`)}"/>
          <path d="M34 98 H126 C126 110 106 115 80 115 C54 115 34 110 34 98 Z" fill="${g(`${u}g4`)}"/>
        </g>
        ${gloss(u, 56, 40, 20, 11, 0.45)}`;
    },

    /* vegetariano */
    veggie(u) {
      const t = [P.bun, P.green, P.tomato, P.cheese, P.bunDeep];
      return `${defs(u, t)}
        <g filter="url(#${u}sh)">
          <path d="${dome(32, 26, 96, 34)}" fill="${g(`${u}g0`)}"/>
          <ellipse cx="60" cy="38" rx="5" ry="2.8" fill="${up(P.cream, 0.1)}" opacity=".9"/>
          <ellipse cx="100" cy="35" rx="5" ry="2.8" fill="${up(P.cream, 0.1)}" opacity=".9"/>
          <path d="${wave(28, 64, 104, 10)} v9 q-13 9 -26 0 t-26 0 t-26 0 t-26 0 z" fill="${g(`${u}g1`)}"/>
          <circle cx="54" cy="84" r="11" fill="${g(`${u}g2`)}"/>
          <circle cx="84" cy="86" r="11" fill="${g(`${u}g2`)}"/>
          <circle cx="108" cy="84" r="10" fill="${g(`${u}g2`)}"/>
          <path d="${slab(34, 90, 92, 12, 6)}" fill="${g(`${u}g3`)}"/>
          <path d="M34 100 H126 C126 111 106 116 80 116 C54 116 34 111 34 100 Z" fill="${g(`${u}g4`)}"/>
        </g>
        ${gloss(u, 56, 42, 20, 11, 0.45)}`;
    },

    /* cachorro-quente */
    hotdog(u) {
      const t = [P.bun, P.bunDeep, '#C8443A', P.cheese, P.potato];
      return `${defs(u, t)}
        <g filter="url(#${u}sh)">
          <path d="M26 74 C26 62 40 56 80 56 C120 56 134 62 134 74 C134 84 120 88 80 88 C40 88 26 84 26 74 Z" fill="${g(`${u}g0`)}"/>
          <path d="${slab(20, 62, 120, 20, 10)}" fill="${g(`${u}g2`)}"/>
          <path d="M30 78 C30 68 46 62 80 62 C114 62 130 68 130 78 C130 88 114 92 80 92 C46 92 30 88 30 78 Z" fill="${g(`${u}g1`)}"/>
          <path d="M34 76 C48 68 60 84 74 76 C88 68 100 84 114 76 L116 82 C102 90 90 74 76 82 C62 90 50 74 36 82 Z" fill="${g(`${u}g3`)}" opacity=".95"/>
          ${[42, 58, 74, 90, 106].map((x) => `<path d="M${x} 70 l7 12" stroke="${dn(P.potato, .18)}" stroke-width="4" style="stroke-linecap:round" fill="none"/>`).join('')}
        </g>
        ${gloss(u, 48, 66, 16, 7, 0.45)}`;
    },

    /* batata frita */
    fries(u) {
      const t = [P.sauza, P.potato, dn(P.potato, 0.1), P.cream];
      return `${defs(u, t)}
        <g filter="url(#${u}sh)">
          ${[[50, 22, -14], [66, 14, -6], [82, 12, 2], [98, 18, 9], [112, 30, 16], [40, 34, -20]].map(([x, y, r]) =>
            `<rect x="${x}" y="${y}" width="13" height="62" rx="6" transform="rotate(${r} ${x + 6} ${y + 30})" fill="${g(`${u}g1`)}"/>`).join('')}
          <path d="${tub(46, 52, 76, 52, 10)}" fill="${g(`${u}g0`)}"/>
          <path d="${tub(46, 52, 76, 22, 0)}" fill="${g(`${u}g2`)}" opacity=".35"/>
          <path d="M52 66 H116" stroke="#FFF" stroke-width="5" opacity=".5" style="stroke-linecap:round" fill="none"/>
          <circle cx="84" cy="88" r="9" fill="${g(`${u}g3`)}" opacity=".85"/>
        </g>
        ${gloss(u, 62, 66, 12, 16, 0.35)}`;
    },

    /* onion rings */
    rings(u) {
      const t = [P.chicken, up(P.chicken, 0.12), P.green];
      return `${defs(u, t)}
        <g filter="url(#${u}sh)">
          <circle cx="58" cy="70" r="30" fill="none" stroke="${g(`${u}g0`)}" stroke-width="15"/>
          <circle cx="100" cy="66" r="28" fill="none" stroke="${g(`${u}g1`)}" stroke-width="15"/>
          <circle cx="78" cy="40" r="22" fill="none" stroke="${g(`${u}g0`)}" stroke-width="13"/>
          <path d="M60 40 q18 -8 34 2" stroke="#FFF2DC" stroke-width="4" opacity=".55" fill="none" style="stroke-linecap:round"/>
          <path d="M46 62 q10 -10 22 -6" stroke="#FFF2DC" stroke-width="4" opacity=".45" fill="none" style="stroke-linecap:round"/>
          <ellipse cx="90" cy="102" rx="16" ry="4" fill="${g(`${u}g2`)}" opacity=".35"/>
        </g>`;
    },

    /* nuggets */
    nuggets(u) {
      const t = [P.chicken, P.sauza, P.cream];
      return `${defs(u, t)}
        <g filter="url(#${u}sh)">
          <path d="M44 96 C34 96 32 84 40 78 C38 68 50 62 60 66 C68 58 84 62 86 72 C96 72 100 84 92 90 C90 98 76 102 66 100 C58 102 48 102 44 96 Z" fill="${g(`${u}g0`)}"/>
          <path d="M84 74 C78 66 86 56 96 58 C106 54 116 62 114 72 C118 82 108 90 98 86 C92 90 84 84 84 74 Z" fill="${g(`${u}g0`)}"/>
          <path d="M62 56 C56 48 64 38 74 40 C82 34 94 40 94 50 C100 58 92 66 82 64 C76 68 66 64 62 56 Z" fill="${g(`${u}g0`)}"/>
          <path d="M22 92 H48 L44 108 A6 6 0 0 1 38 112 H32 A6 6 0 0 1 26 108 Z" fill="${g(`${u}g1`)}"/>
          <ellipse cx="35" cy="94" rx="13" ry="4.5" fill="${g(`${u}g2`)}"/>
        </g>
        ${gloss(u, 66, 72, 16, 8, 0.4)}`;
    },

    /* copo de refrigerante */
    cup(u, tone = '#49BDF6') {
      const t = [tone, P.cream, dn(tone, 0.25)];
      return `${defs(u, t)}
        <g filter="url(#${u}sh)">
          <path d="M56 40 h48 v-8 a4 4 0 0 0 -4 -4 h-40 a4 4 0 0 0 -4 4 z" fill="${g(`${u}g2`)}"/>
          <path d="${tub(56, 40, 48, 62, 8)}" fill="${g(`${u}g0`)}"/>
          <path d="${tub(56, 40, 48, 16, 0)}" fill="#FFF" opacity=".22"/>
          <path d="M96 44 l14 -34" stroke="${P.sauza}" stroke-width="8" style="stroke-linecap:round" fill="none"/>
          <ellipse cx="80" cy="58" rx="16" ry="6" fill="#FFF" opacity=".28"/>
        </g>
        ${gloss(u, 70, 62, 8, 18, 0.35)}`;
    },

    /* milkshake */
    shake(u) {
      const t = [P.cream, '#FF8FB4', P.cream, dn('#FF8FB4', 0.3)];
      return `${defs(u, t)}
        <g filter="url(#${u}sh)">
          <path d="${tub(52, 54, 56, 56, 9)}" fill="${g(`${u}g1`)}"/>
          <path d="M54 56 C48 38 60 26 80 26 C100 26 112 38 106 56 C98 62 62 62 54 56 Z" fill="${g(`${u}g0`)}"/>
          <circle cx="80" cy="18" r="11" fill="${g(`${u}g1`)}"/>
          <path d="M92 30 l16 -30" stroke="${P.sauza}" stroke-width="8" style="stroke-linecap:round" fill="none"/>
          <path d="M60 58 q10 10 20 0 q10 10 20 0 q-10 12 -20 0 q-10 12 -20 0 z" fill="${g(`${u}g2`)}" opacity=".9"/>
          <path d="M58 76 H104" stroke="#FFF" stroke-width="5" opacity=".45" style="stroke-linecap:round" fill="none"/>
        </g>
        ${gloss(u, 72, 44, 14, 8, 0.55)}`;
    },

    /* suco / limonada */
    juice(u) {
      const t = ['#F5DE4C', P.ice, '#EDE7DA'];
      return `${defs(u, t)}
        <g filter="url(#${u}sh)">
          <path d="${tub(54, 46, 52, 62, 10)}" fill="${g(`${u}g2`)}"/>
          <path d="${tub(56, 52, 48, 52, 8)}" fill="${g(`${u}g0`)}"/>
          <circle cx="70" cy="72" r="9" fill="${g(`${u}g1`)}" opacity=".8"/>
          <circle cx="88" cy="82" r="7" fill="${g(`${u}g1`)}" opacity=".7"/>
          <circle cx="104" cy="34" r="16" fill="${g(`${u}g0`)}"/>
          <g opacity=".85">
            ${Array.from({ length: 6 }, (_, i) => `<path d="M104 34 L${104 + 15 * Math.cos((i * Math.PI) / 3)} ${34 + 15 * Math.sin((i * Math.PI) / 3)}" stroke="#FFF6DA" stroke-width="2.5" fill="none"/>`).join('')}
          </g>
          <path d="M96 44 l18 -34" stroke="${P.green}" stroke-width="7" style="stroke-linecap:round" fill="none"/>
        </g>
        ${gloss(u, 66, 60, 7, 16, 0.4)}`;
    },

    /* cold brew */
    coffee(u) {
      const t = ['#5B3320', P.ice, '#EDE7DA', '#F2E3CB'];
      return `${defs(u, t)}
        <g filter="url(#${u}sh)">
          <path d="${tub(54, 44, 52, 64, 10)}" fill="${g(`${u}g2`)}"/>
          <path d="${tub(56, 50, 48, 54, 8)}" fill="${g(`${u}g0`)}"/>
          <rect x="62" y="56" width="16" height="16" rx="4" transform="rotate(-12 70 64)" fill="${g(`${u}g1`)}" opacity=".75"/>
          <rect x="84" y="72" width="15" height="15" rx="4" transform="rotate(14 91 79)" fill="${g(`${u}g1`)}" opacity=".6"/>
          <path d="M104 40 C110 30 104 20 96 20" stroke="${g(`${u}g3`)}" stroke-width="5" fill="none" style="stroke-linecap:round"/>
          <path d="M96 44 l16 -30" stroke="${P.sauza}" stroke-width="7" style="stroke-linecap:round" fill="none"/>
        </g>
        ${gloss(u, 66, 58, 7, 15, 0.32)}`;
    },

    /* brownie */
    brownie(u) {
      const t = [P.choco, P.cream, dn(P.choco, 0.3)];
      return `${defs(u, t)}
        <g filter="url(#${u}sh)">
          <path d="M40 62 H120 A10 10 0 0 1 130 72 V96 A10 10 0 0 1 120 106 H40 A10 10 0 0 1 30 96 V72 A10 10 0 0 1 40 62 Z" fill="${g(`${u}g0`)}"/>
          <path d="M40 62 H120 A10 10 0 0 1 128 68 H32 A10 10 0 0 1 40 62 Z" fill="${g(`${u}g2`)}" opacity=".7"/>
          <path d="M64 50 C56 50 54 40 62 36 C70 30 84 32 86 42 C96 46 92 58 80 58 C72 60 66 56 64 50 Z" fill="${g(`${u}g1`)}"/>
          <circle cx="98" cy="80" r="5" fill="${dn(P.choco, .5)}" opacity=".55"/>
          <circle cx="60" cy="88" r="4" fill="${dn(P.choco, .5)}" opacity=".5"/>
        </g>
        ${gloss(u, 56, 70, 18, 7, 0.35)}`;
    },

    /* petit gâteau */
    cake(u) {
      const t = [P.choco, P.cream, '#EDE0CC', '#C8443A'];
      return `${defs(u, t)}
        <g filter="url(#${u}sh)">
          <ellipse cx="80" cy="106" rx="46" ry="8" fill="${g(`${u}g2`)}"/>
          <path d="M46 74 H114 C114 96 100 106 80 106 C60 106 46 96 46 74 Z" fill="${g(`${u}g0`)}"/>
          <ellipse cx="80" cy="74" rx="34" ry="7" fill="${g(`${u}g2`)}"/>
          <path d="M70 72 C64 84 68 96 80 96 C92 96 96 84 90 72 Z" fill="${dn(P.choco, .45)}"/>
          <path d="M60 62 C52 62 50 50 58 44 C66 36 82 38 86 48 C96 50 96 64 84 66 C76 70 66 68 60 62 Z" fill="${g(`${u}g1`)}"/>
          <circle cx="98" cy="40" r="6" fill="${g(`${u}g3`)}"/>
          <path d="M98 34 q2 -10 -4 -14" stroke="${P.green}" stroke-width="3.5" fill="none" style="stroke-linecap:round"/>
        </g>
        ${gloss(u, 62, 82, 12, 6, 0.3)}`;
    },

    /* açaí na tigela */
    bowl(u) {
      const t = ['#8E5BC0', P.grape, P.cream, dn(P.grape, 0.25)];
      return `${defs(u, t)}
        <g filter="url(#${u}sh)">
          <path d="M40 56 H120 C120 88 104 104 80 104 C56 104 40 88 40 56 Z" fill="${g(`${u}g1`)}"/>
          <ellipse cx="80" cy="56" rx="40" ry="10" fill="${g(`${u}g0`)}"/>
          <ellipse cx="66" cy="54" rx="7" ry="3.4" fill="${P.cream}" opacity=".92"/>
          <ellipse cx="88" cy="58" rx="6" ry="3" fill="${P.cream}" opacity=".9"/>
          <ellipse cx="100" cy="52" rx="5" ry="2.6" fill="${P.cream}" opacity=".85"/>
          ${[[58, 50], [74, 46], [92, 48], [70, 60], [98, 58]].map(([x, y]) =>
            `<circle cx="${x}" cy="${y}" r="3.4" fill="${up(P.potato, 0.1)}"/>`).join('')}
          <path d="M40 56 H120" stroke="${g(`${u}g3`)}" stroke-width="4" opacity=".5" fill="none"/>
        </g>
        ${gloss(u, 62, 74, 12, 8, 0.3)}`;
    },
  };

  /* ── calagem: medida sobre a caixa de tinta real de cada glifo ─────────
     (cx, cy) = centro da tinta; s = escala que dá a mesma presença visual
     a um copo alto e a um hambúrguer largo. Gerado por medição, não no olho. */
  const FIT = {
    smash:   { cx: 79.8, cy: 72.5, s: 1.112 },
    burger:  { cx: 79.8, cy: 74.8, s: 1.101 },
    chicken: { cx: 79.8, cy: 74.8, s: 1.155 },
    veggie:  { cx: 79.5, cy: 76.3, s: 1.096 },
    hotdog:  { cx: 79.8, cy: 78.5, s: 0.943 },
    fries:   { cx: 81.5, cy: 68.5, s: 1.081 },
    rings:   { cx: 77.8, cy: 64.8, s: 0.967 },
    nuggets: { cx: 69.0, cy: 79.8, s: 1.208 },
    shake:   { cx: 80.8, cy: 63.0, s: 0.911 },
    cup:     { cx: 83.8, cy: 63.3, s: 1.067 },
    juice:   { cx: 86.8, cy: 67.5, s: 1.001 },
    coffee:  { cx: 83.5, cy: 69.5, s: 1.035 },
    brownie: { cx: 79.8, cy: 74.8, s: 1.091 },
    cake:    { cx: 79.8, cy: 71.3, s: 1.147 },
    bowl:    { cx: 79.8, cy: 78.5, s: 1.220 },
  };

  /* ── API ─────────────────────────────────────────────────────────────── */
  function glyph(name, size) {
    const fn = GLYPHS[name] || GLYPHS.burger;
    const u = uid('c');
    const w = size || 160;
    const h = (w * 142) / 160;
    const f = FIT[name] || { cx: 80, cy: 70, s: 1 };
    // centro da tinta no centro óptico do quadro, com folga para a sombra
    const frame = `translate(80 63) scale(${f.s}) translate(${-f.cx} ${-f.cy})`;
    return `<svg viewBox="0 -8 160 142" width="${w}" height="${h}"
      xmlns="http://www.w3.org/2000/svg" style="stroke:none" aria-hidden="true" focusable="false"><g transform="${frame}">${fn(u)}</g></svg>`;
  }

  return { glyph, up, dn, mix, P };
})();
