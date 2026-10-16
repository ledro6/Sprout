import React from 'react';
import {C, DROP, DROP_C, LEAF, LEAF_C, M, RGB, SHARE, clamp01, easeInOut, mix, rgb} from '../tokens';

// Волна полива: расходится из точки (Front.point), по фигурке проходит гребень —
// синеет и раздаётся до 1.15, перед ним и за ним ямки до 0.66.
export type Wave = {t0: number; x: number; y: number; strength?: number};
// Перекраска темы — тот же круг, что у волны.
export type Flip = {t0: number; x: number; y: number; to: 'dark' | 'light'; seconds?: number};
// Сбегание к точке (Front.collapse) — финал, из точки вырастает логотип.
export type Collapse = {t0: number; x: number; y: number; seconds: number};

const crestOf = (p: number) => (p <= 0 || p >= 1 ? 0 : Math.exp(-Math.pow((p - 0.5) / 0.13, 2)));
const valleyOf = (p: number) =>
  p <= 0 || p >= 1 ? 0 : Math.exp(-Math.pow((p - 0.2) / 0.08, 2)) + Math.exp(-Math.pow((p - 0.8) / 0.08, 2));

type Props = {
  w: number;
  h: number;
  k: number; // px на pt
  t: number; // секунды
  waves: Wave[];
  flips?: Flip[];
  collapse?: Collapse;
  base: 'light' | 'dark';
};

export const Pattern: React.FC<Props> = ({w, h, k, t, waves, flips = [], collapse, base}) => {
  const pitchX = 74 * k;
  const pitchY = 60 * k;
  const cols = Math.ceil(w / pitchX) + 2;
  const rows = Math.ceil(h / pitchY) + 2;
  const fig = 0.78 * k;

  // Тема в точке: начальная, потом каждая перекраска кругом.
  const themeAt = (x: number, y: number): number => {
    let dark = base === 'dark' ? 1 : 0;
    for (const f of flips) {
      const reach = Math.hypot(Math.max(f.x, w - f.x), Math.max(f.y, h - f.y));
      const r = easeInOut((t - f.t0) / (f.seconds ?? 1.5)) * reach;
      if (t > f.t0 && Math.hypot(x - f.x, y - f.y) < r) dark = f.to === 'dark' ? 1 : 0;
    }
    return dark;
  };

  const els: React.ReactNode[] = [];
  for (let r = -1; r < rows; r++) {
    for (let c = -1; c < cols; c++) {
      const x = c * pitchX + (r % 2 ? pitchX / 2 : 0);
      const y = r * pitchY;
      const isLeaf = (r + c) % 2 === 0;
      let crest = 0;
      let valley = 0;
      for (const wv of waves) {
        if (t < wv.t0) continue;
        const dist = Math.hypot(x - wv.x, y - wv.y) / k;
        const turn = Math.min(dist / M.reach, 1);
        const p = ((t - wv.t0) / M.cheerSeconds - turn * (1 - M.popSpan)) / M.popSpan;
        const s = wv.strength ?? 1;
        crest = Math.max(crest, crestOf(p) * s);
        valley = Math.max(valley, valleyOf(p) * s);
      }
      let scale = 1 + M.popAmp * crest - (1 - M.popDip) * 0.55 * valley;
      if (collapse && t > collapse.t0) {
        const corner = Math.hypot(Math.max(collapse.x, w - collapse.x), Math.max(collapse.y, h - collapse.y));
        const turn = 1 - Math.min(Math.hypot(x - collapse.x, y - collapse.y) / corner, 1);
        const p = ((t - collapse.t0) / collapse.seconds - turn * (1 - M.popSpan)) / M.popSpan;
        scale *= 1 - easeInOut(p);
      }
      if (scale <= 0.01) continue;
      const dark = themeAt(x, y);
      const bg: RGB = dark ? C.bgDark : C.bgLight;
      const rest = dark ? mix(bg, C.vividGreen, SHARE.restDark) : mix(bg, C.palePattern, SHARE.restLight + 0.1);
      const crestCol = mix(bg, C.waveBlue, dark ? SHARE.waveDark : SHARE.waveLight);
      const col = mix(rest, crestCol, clamp01(crest));
      const [cx, cy] = isLeaf ? LEAF_C : DROP_C;
      els.push(
        <path
          key={`${r}-${c}`}
          d={isLeaf ? LEAF : DROP}
          fill={rgb(col)}
          transform={`translate(${x} ${y}) scale(${fig * scale}) translate(${-cx} ${-cy})`}
        />,
      );
    }
  }

  // Фон: базовая тема и круги перекраски поверх.
  const discs = flips
    .filter((f) => t > f.t0)
    .map((f, i) => {
      const reach = Math.hypot(Math.max(f.x, w - f.x), Math.max(f.y, h - f.y));
      const r = easeInOut((t - f.t0) / (f.seconds ?? 1.5)) * reach;
      return <circle key={i} cx={f.x} cy={f.y} r={r} fill={rgb(f.to === 'dark' ? C.bgDark : C.bgLight)} />;
    });

  return (
    <svg width={w} height={h} style={{position: 'absolute', inset: 0}}>
      <rect width={w} height={h} fill={rgb(base === 'dark' ? C.bgDark : C.bgLight)} />
      {discs}
      {els}
    </svg>
  );
};
