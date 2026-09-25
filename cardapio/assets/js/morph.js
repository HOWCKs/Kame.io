/* ═══════════════════════════════════════════════════════════════════════
   MORPHIS · morph.js
   O núcleo CLAY MORPHIST: uma forma de argila que respira, morfa e cede
   ao toque. A "3D" é extrusão real — empilhamos N cópias do mesmo
   contorno, deslocadas para baixo e escurecidas, e desenhamos a face de
   cima por último. Sem WebGL, sem dependência: SVG + requestAnimationFrame.
   ═══════════════════════════════════════════════════════════════════════ */

const Morph = (() => {
  const TAU = Math.PI * 2;
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const lerp = (a, b, t) => a + (b - a) * t;
  const easeInOut = (t) => (t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2);

  const N = 42;                 // pontos do contorno
  const BASE = 88;              // raio base (viewBox 280)
  const LAYERS = 13;            // fatias da extrusão
  const DEPTH = 2.4;            // px entre fatias

  /* ── formas: somatório de harmônicos em coordenadas polares ─────────── */
  const HARMONICS = [
    [{ k: 2, a: 0.10, p: 0.0 }, { k: 3, a: 0.07, p: 1.1 }],
    [{ k: 3, a: 0.13, p: 0.6 }, { k: 5, a: 0.05, p: 2.2 }],
    [{ k: 4, a: 0.11, p: 1.6 }, { k: 2, a: 0.06, p: 0.4 }, { k: 6, a: 0.03, p: 3.0 }],
    [{ k: 5, a: 0.08, p: 0.3 }, { k: 3, a: 0.09, p: 2.8 }, { k: 7, a: 0.03, p: 1.0 }],
  ];

  function radii(h) {
    const out = new Array(N);
    for (let i = 0; i < N; i++) {
      const th = (i / N) * TAU;
      let r = 1;
      for (const { k, a, p } of h) r += a * Math.cos(k * th + p);
      out[i] = r;
    }
    return out;
  }
  const PRESETS = HARMONICS.map(radii);

  /* ── contorno → path (Catmull-Rom fechado) ──────────────────────────── */
  function pathFromPoints(pts) {
    const n = pts.length;
    let d = `M${pts[0][0].toFixed(1)},${pts[0][1].toFixed(1)}`;
    for (let i = 0; i < n; i++) {
      const p0 = pts[(i - 1 + n) % n], p1 = pts[i], p2 = pts[(i + 1) % n], p3 = pts[(i + 2) % n];
      const c1x = p1[0] + (p2[0] - p0[0]) / 6, c1y = p1[1] + (p2[1] - p0[1]) / 6;
      const c2x = p2[0] - (p3[0] - p1[0]) / 6, c2y = p2[1] - (p3[1] - p1[1]) / 6;
      d += `C${c1x.toFixed(1)},${c1y.toFixed(1)} ${c2x.toFixed(1)},${c2y.toFixed(1)} ${p2[0].toFixed(1)},${p2[1].toFixed(1)}`;
    }
    return d + 'Z';
  }

  /* ── cor ─────────────────────────────────────────────────────────────── */
  const hex = (h) => {
    const s = h.replace('#', '');
    const p = s.length === 3 ? s.split('').map((c) => c + c) : [s.slice(0, 2), s.slice(2, 4), s.slice(4, 6)];
    return p.map((v) => parseInt(v, 16));
  };
  const toHex = (a) => '#' + a.map((v) => clamp(Math.round(v), 0, 255).toString(16).padStart(2, '0')).join('');
  const mix = (a, b, t) => { const x = hex(a), y = hex(b); return toHex(x.map((v, i) => lerp(v, y[i], t))); };

  /* ── motor ──────────────────────────────────────────────────────────── */
  class MorphEngine {
    constructor(cfg) {
      this.stage = cfg.stage;                 // wrapper com a perspectiva
      this.layersG = cfg.layers;              // <g> das fatias
      this.face = cfg.face;                   // path da face de cima
      this.gloss = cfg.gloss;                 // ellipse de brilho
      this.shadow = cfg.shadow;               // sombra no chão
      this.reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

      this.from = PRESETS[0].slice();
      this.to = PRESETS[1].slice();
      this.t = 0;
      this.duration = 6200;
      this.index = 0;

      this.pointer = { x: 0, y: 0, tx: 0, ty: 0, active: false };
      this.spin = { v: 0, a: 0 };             // rotação da forma com inércia
      this.impulse = 0;
      this.color = cfg.color || '#FF6A3D';
      this.targetColor = this.color;
      this.visible = true;
      this.frame = null;

      // amarrado aqui (e não depois) porque o observador já pode disparar
      // um frame antes de terminarmos o construtor.
      this._loop = this._loop.bind(this);

      this._build();
      this._bind();
      this._observe();
      this.render(performance.now());
      if (!this.reduced) this.frame = requestAnimationFrame(this._loop);
    }

    _build() {
      // fatias da extrusão: mais escuras e mais abaixo atrás, mais claras na frente
      this.slices = [];
      let html = '';
      for (let i = 0; i < LAYERS; i++) {
        html += `<path data-slice="${i}" d=""/>`;
      }
      this.layersG.innerHTML = html;
      this.slices = Array.from(this.layersG.querySelectorAll('path'));

      // gradiente da face de cima + brilho
      const NS = 'http://www.w3.org/2000/svg';
      const defs = document.createElementNS(NS, 'defs');
      defs.innerHTML = `
        <radialGradient id="faceGrad" cx="34%" cy="24%" r="86%">
          <stop offset="0" stop-color="#FFB08A"/>
          <stop offset=".55" stop-color="#FF7A45"/>
          <stop offset="1" stop-color="#C43C1B"/>
        </radialGradient>
        <radialGradient id="glossGrad">
          <stop offset="0" stop-color="#FFF6EA" stop-opacity=".85"/>
          <stop offset="1" stop-color="#FFF6EA" stop-opacity="0"/>
        </radialGradient>`;
      const svg = this.layersG.ownerSVGElement;
      svg.insertBefore(defs, svg.firstChild);
      this.face.setAttribute('fill', 'url(#faceGrad)');
      this.stops = defs.querySelectorAll('#faceGrad stop');
      this.sparkG = document.getElementById('morphSpark');
      if (this.sparkG) {
        this.sparks = Array.from({ length: 3 }, (_, i) => {
          const c = document.createElementNS(NS, 'circle');
          c.setAttribute('r', String(4 + i * 1.5));
          c.setAttribute('fill', '#FFF6EA');
          c.setAttribute('opacity', String(0.5 - i * 0.12));
          this.sparkG.appendChild(c);
          return { el: c, a: (i / 3) * TAU, sp: 0.2 + i * 0.06, r: 78 + i * 12 };
        });
      }
    }

    _bind() {
      const el = this.stage;
      const move = (e) => {
        const r = el.getBoundingClientRect();
        const p = e.touches ? e.touches[0] : e;
        this.pointer.tx = clamp(((p.clientX - r.left) / r.width) * 2 - 1, -1, 1);
        this.pointer.ty = clamp(((p.clientY - r.top) / r.height) * 2 - 1, -1, 1);
        this.pointer.active = true;
        this.spin.v += (this.pointer.tx - this.pointer.x) * 0.35;
      };
      const leave = () => { this.pointer.active = false; this.pointer.tx = 0; this.pointer.ty = 0; };

      el.addEventListener('pointermove', move);
      el.addEventListener('pointerleave', leave);
      el.addEventListener('pointerdown', (e) => {
        this.impulse = 1;
        this.spin.v += 2.4;
        move(e);
      });
      el.addEventListener('touchmove', move, { passive: true });
      el.addEventListener('touchend', leave);
      // o palco é decorativo, mas não invisível ao teclado: Enter/Espaço "amassa"
      el.tabIndex = 0;
      el.setAttribute('role', 'img');
      el.setAttribute('aria-label', 'Forma de argila interativa que reage ao cursor e representa o cardápio');
      el.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); this.impulse = 1; }
      });
    }

    _observe() {
      if (!('IntersectionObserver' in window)) return;
      new IntersectionObserver(([entry]) => {
        this.visible = entry.isIntersecting;
        if (this.visible && !this.reduced && !this.frame) this.frame = requestAnimationFrame(this._loop);
      }, { threshold: 0.05 }).observe(this.stage);
    }

    setColor(hex) { this.targetColor = hex; }

    _loop(now) {
      this.frame = null;
      if (this.visible) {
        this.render(now);
        if (!this.reduced) this.frame = requestAnimationFrame(this._loop);
      }
    }

    /* ── um passe de desenho ─────────────────────────────────────────── */
    render(now) {
      const t = now || 0;

      // 1. ciclo de morph entre presets
      if (!this.reduced) {
        this.t += 16.6;
        if (this.t >= this.duration) {
          this.t = 0;
          this.index = (this.index + 1) % PRESETS.length;
          this.from = this.to.slice();
          this.to = PRESETS[(this.index + 1) % PRESETS.length];
        }
      }
      const k = easeInOut(clamp(this.t / this.duration, 0, 1));

      // 2. ponteiro: puxa a matéria na direção do dedo/cursor
      this.pointer.x = lerp(this.pointer.x, this.pointer.tx, 0.12);
      this.pointer.y = lerp(this.pointer.y, this.pointer.ty, 0.12);
      const pd = Math.hypot(this.pointer.x, this.pointer.y);
      const pa = Math.atan2(this.pointer.y, this.pointer.x);

      // 3. impulso elástico (clique / toque)
      this.impulse *= 0.90;
      this.spin.v *= 0.93;
      this.spin.a += this.spin.v * 0.016 + (this.reduced ? 0 : 0.0016);

      const squash = 1 - this.impulse * 0.10 - pd * 0.05;
      const stretch = 1 + this.impulse * 0.07;

      // 4. contorno deformado
      const pts = new Array(N);
      for (let i = 0; i < N; i++) {
        let th = (i / N) * TAU;
        let r = lerp(this.from[i], this.to[i], k) * BASE;
        // respiração contínua (desligada com movimento reduzido)
        if (!this.reduced) r += Math.sin(th * 3 + t / 900) * 2.2 + Math.sin(th * 5 - t / 1300) * 1.4;
        // puxão direcional
        if (this.pointer.active) {
          const d = Math.cos(th - pa);
          r += pd * 16 * Math.max(0, d) * Math.max(0, d);
        }
        r *= 1 + this.impulse * 0.05;

        const x = Math.cos(th + this.spin.a) * r * stretch;
        const y = Math.sin(th + this.spin.a) * r * squash;
        pts[i] = [x, y];
      }
      const d = pathFromPoints(pts);

      // 5. extrusão: fatias empilhadas, escurecidas em direção ao fundo
      const col = mix(this.color, this.targetColor, 0.08);
      this.color = col;
      for (let i = 0; i < LAYERS; i++) {
        const p = i / (LAYERS - 1);
        const slice = this.slices[i];
        slice.setAttribute('d', d);
        slice.setAttribute('transform', `translate(0 ${((LAYERS - 1 - i) * DEPTH).toFixed(1)})`);
        slice.setAttribute('fill', mix(mix(col, '#2A1206', 0.62), col, p));
      }
      this.face.setAttribute('d', d);

      // 6. gradiente da face acompanha a paleta
      if (this.stops) {
        this.stops[0].setAttribute('stop-color', mix(col, '#FFFFFF', 0.48));
        this.stops[1].setAttribute('stop-color', col);
        this.stops[2].setAttribute('stop-color', mix(col, '#2A1206', 0.45));
      }

      // 7. brilho especular e faíscas orbitando
      if (this.gloss) {
        const gx = -30 - this.pointer.x * 12;
        const gy = -44 - this.pointer.y * 10;
        this.gloss.setAttribute('cx', gx.toFixed(1));
        this.gloss.setAttribute('cy', gy.toFixed(1));
        this.gloss.setAttribute('rx', (44 + this.impulse * 6).toFixed(1));
        this.gloss.setAttribute('ry', (28 - this.impulse * 3).toFixed(1));
      }
      if (this.sparks) {
        for (const s of this.sparks) {
          s.a += 0.004 + s.sp * 0.002;
          s.el.setAttribute('cx', (Math.cos(s.a) * s.r).toFixed(1));
          s.el.setAttribute('cy', (Math.sin(s.a) * s.r * 0.8 - 10).toFixed(1));
        }
      }

      // 8. inclinação 3D do palco + sombra no chão
      if (this.stage) {
        const ry = (this.pointer.x * 13).toFixed(2);
        const rx = (-this.pointer.y * 11).toFixed(2);
        this.stage.style.transform = `perspective(1000px) rotateX(${rx}deg) rotateY(${ry}deg)`;
      }
      if (this.shadow) {
        const s = 1 - pd * 0.16 - this.impulse * 0.12;
        this.shadow.style.transform = `translateX(${(-this.pointer.x * 14).toFixed(1)}px) scale(${s.toFixed(3)})`;
        this.shadow.style.opacity = (0.85 - pd * 0.2).toFixed(2);
      }
    }
  }

  /* ── blobs estáticos/leves (marca, estado vazio) ────────────────────── */
  function staticBlob(el, { points = 26, wobble = 0.08, seed = 0 } = {}) {
    const rs = [];
    for (let i = 0; i < points; i++) rs.push(1 + wobble * Math.sin(i * 1.7 + seed) + wobble * 0.6 * Math.cos(i * 0.9 - seed));
    const pts = rs.map((r, i) => {
      const th = (i / points) * TAU;
      return [Math.cos(th) * r * 42, Math.sin(th) * r * 42];
    });
    el.setAttribute('d', pathFromPoints(pts));
  }

  function deflatedBlob(el) {
    const pts = [];
    for (let i = 0; i < 24; i++) {
      const th = (i / 24) * TAU;
      const r = 40 + Math.sin(i * 2.1) * 3 + Math.sin(i * 0.7) * 6;
      pts.push([Math.cos(th) * r, Math.sin(th) * r * 0.62 + 12]);
    }
    el.setAttribute('d', pathFromPoints(pts));
  }

  return { MorphEngine, staticBlob, deflatedBlob, pathFromPoints, mix };
})();
