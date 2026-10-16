// 2D-слой поверх 3D-сцены: заголовки сцен, HUD-рамка и финальный логотип.
// Состояния нет — всё считается из времени, поэтому кадры воспроизводимы.
import React from 'react';
import {AbsoluteFill, useCurrentFrame, useVideoConfig} from 'remotion';
import {
  COL,
  FPS,
  H,
  LOGO_BOX,
  LOGO_DROPS,
  LOGO_LEAVES,
  LOGO_PARTS,
  M,
  SCENES,
  TOTAL,
  W,
  clamp01,
  easeInOut,
  easeOut,
  sceneAt,
  sui,
} from './shared';
import type {SceneSpec} from './shared';
import {FONT} from '../tokens';

// ---------- Общая типографика заголовка ----------
const PAD = 0.12; // запас в em сверху и снизу: глифы с выносными элементами не режутся маской и background-clip
const LH = 0.92;
const HX = 72;
const HY = 190;
const HW = W - 2 * HX;
const TRACK = -0.045;
const OUT = 0.22; // выход заголовка — последние 0.22 с сцены
const MONO = "ui-monospace, 'SF Mono', Menlo, 'DejaVu Sans Mono', monospace";

// Измеряем ширину строки на canvas: размер подбирается по самой длинной строке.
let mctx: CanvasRenderingContext2D | null | undefined;
const emWidth = (s: string) => {
  if (mctx === undefined) mctx = typeof document === 'undefined' ? null : document.createElement('canvas').getContext('2d');
  const n = Array.from(s).length;
  if (!mctx) return n * 0.58;
  mctx.font = `800 100px ${FONT}`;
  return mctx.measureText(s).width / 100 + TRACK * n;
};
const fitSize = (lines: string[]) => Math.min(230, Math.floor(HW / Math.max(...lines.map(emWidth))));

// Блик проходит по буквам: фон-градиент обрезается по тексту, позиция считается от 2.5× ширины.
const inkStyle = (size: number, sweep: number): React.CSSProperties => ({
  fontFamily: FONT,
  fontWeight: 800,
  fontSize: size,
  lineHeight: LH,
  letterSpacing: `${TRACK}em`,
  whiteSpace: 'pre',
  width: 'fit-content',
  padding: `${PAD * size}px 0`,
  color: 'transparent',
  WebkitTextFillColor: 'transparent',
  backgroundImage:
    'linear-gradient(105deg, rgba(255,255,255,0) 42%, #ffffff 50%, rgba(255,255,255,0) 58%), linear-gradient(180deg, #ffffff 0%, #c4cbc7 100%)',
  backgroundSize: '250% 100%, 100% 100%',
  backgroundRepeat: 'no-repeat',
  backgroundPosition: `${((1.25 - sweep) / 1.5) * 100}% 0, 0 0`,
  WebkitBackgroundClip: 'text',
  backgroundClip: 'text',
});

// Заголовок сцены: строки выезжают из маски, блик и выход в последние 0.22 с.
const Headline: React.FC<{lines: string[]; sub?: string; local: number; dur: number}> = ({lines, sub, local, dur}) => {
  const size = fitSize(lines);
  const lh = LH * size;
  const bottom = HY + lines.length * lh;
  const o = clamp01((local - (dur - OUT)) / OUT) ** 2;
  const sweep = -0.2 + 1.4 * easeInOut(clamp01((local - 0.05) / 0.45));
  const subP = easeOut(clamp01((local - 0.15) / 0.35));
  return (
    <>
      <div
        style={{
          position: 'absolute',
          left: HX,
          top: HY - PAD * size,
          width: HW,
          opacity: 1 - o,
          filter: `blur(${o * 14}px)`,
          transform: `translateY(${-o * 44}px)`,
        }}
      >
        {lines.map((ln, i) => {
          const e = easeOut(clamp01((local - i * 0.06) / 0.3));
          return (
            <div key={i} style={{overflow: 'hidden', marginBottom: -2 * PAD * size}}>
              <div
                style={{
                  ...inkStyle(size, sweep),
                  transformOrigin: '0 100%',
                  transform: `translateY(${(1 - e) * 1.2 * size}px) scale(${1 + 0.06 * (1 - e)})`,
                  filter: `blur(${(1 - e) * 14}px)`,
                }}
              >
                {ln}
              </div>
            </div>
          );
        })}
      </div>
      {/* Тонкая линия под заголовком — выравнивает текстовый блок по сетке */}
      <div
        style={{
          position: 'absolute',
          left: HX,
          top: bottom + 34,
          width: HW,
          height: 1.5,
          background: 'rgba(255,255,255,0.42)',
          transformOrigin: '0 50%',
          transform: `scaleX(${easeOut(clamp01((local - 0.1) / 0.45))})`,
          opacity: 1 - o,
        }}
      />
      {sub && (
        <div
          style={{
            position: 'absolute',
            left: HX,
            top: bottom + 62,
            width: HW,
            fontFamily: "'Inter', 'Inter Display', sans-serif",
            fontSize: 36,
            fontWeight: 500,
            lineHeight: 1.25,
            letterSpacing: '0.02em',
            color: 'rgba(255,255,255,0.65)',
            opacity: subP * (1 - o),
            transform: `translateY(${(1 - subP) * 12 - o * 30}px)`,
            filter: `blur(${(1 - subP) * 6 + o * 12}px)`,
          }}
        >
          {sub}
        </div>
      )}
    </>
  );
};

// Hook-сцена: слова бьют по одному, каждый удар — толчок камеры; затем капля падает из кадра.
const HOOK_WORDS = ['Ты', 'забыл', 'полить'];
const HOOK_AT = [0, 0.45, 0.9];
const DROP_D = 'M16 2 C16 2 2 20 2 32 A14 14 0 0 0 30 32 C30 20 16 2 16 2 Z';

const Hook: React.FC<{local: number; dur: number}> = ({local, dur}) => {
  const size = fitSize(HOOK_WORDS);
  const lh = LH * size;
  const o = clamp01((local - (dur - OUT)) / OUT) ** 2;
  let sx = 0;
  let sy = 0;
  for (const t0 of HOOK_AT) {
    const l = local - t0;
    if (l > 0 && l < 0.5) {
      const d = Math.exp(-l * 12);
      sx += 9 * d * Math.sin(l * 70);
      sy += 6 * d * Math.cos(l * 55);
    }
  }

  // Точка отрыва — у низа последнего слова, под «ить».
  const dl = local - 1.6;
  const x0 = HX + emWidth('полить') * size * 0.7;
  const y0 = HY + 2 * lh + 0.74 * size;
  const gravity = 4200;
  const dropY = y0 + 0.5 * gravity * dl * dl;
  const dropX = x0 + 16 * dl * dl;
  const pop = clamp01(dl / 0.12);
  const dropOp = clamp01(dl / 0.05) * (1 - clamp01((dl - 0.6) / 0.4));

  return (
    <>
      <div
        style={{
          position: 'absolute',
          left: HX,
          top: HY - PAD * size,
          opacity: 1 - o,
          filter: `blur(${o * 14}px)`,
          transform: `translate(${sx}px, ${sy - o * 40}px)`,
        }}
      >
        {HOOK_WORDS.map((w, i) => {
          const l = local - HOOK_AT[i];
          if (l < 0) return null;
          const s = sui(l * FPS, FPS, 0.5, 0.3);
          return (
            <div
              key={i}
              style={{
                ...inkStyle(size, 1.2),
                position: 'absolute',
                left: 0,
                top: i * lh,
                transformOrigin: '0 50%',
                transform: `scale(${1.4 - 0.4 * s})`,
                filter: `blur(${(1 - clamp01(l / 0.2)) * 16}px)`,
                opacity: clamp01(l / 0.05),
              }}
            >
              {w}
            </div>
          );
        })}
      </div>
      {dl > 0 && dl < 1 && dropOp > 0 && (
        <svg
          width={32}
          height={46}
          viewBox="0 0 32 46"
          style={{
            position: 'absolute',
            left: dropX - 16,
            top: dropY - 2,
            opacity: dropOp,
            transformOrigin: '50% 0%',
            transform: `scale(${0.4 + 0.6 * pop}, ${(0.4 + 0.6 * pop) * (1 + Math.min(dl * 2.2, 0.55))})`,
            filter: `drop-shadow(0 0 10px rgba(71,181,228,0.95)) drop-shadow(0 0 3px rgba(71,181,228,0.9))`,
          }}
        >
          <path d={DROP_D} fill={COL.water} />
        </svg>
      )}
    </>
  );
};

// ---------- HUD ----------
const FEATURES = SCENES.filter((s) => s.sub);
const FEATURE_LABEL: Record<string, string> = {
  greets: 'КАРТОЧКА ДНЯ',
  knows: 'VISION',
  names: 'APPLE INTELLIGENCE',
  heals: 'ДИАГНОСТИКА',
  answers: 'APPLE INTELLIGENCE',
  draws: 'IMAGE PLAYGROUND',
  orbits: 'ПЛАНЕТАРИЙ',
  wrist: 'APPLE WATCH',
  family: 'ICLOUD',
  private: 'БЕЗ АККАУНТА',
};
const CORNERS = [
  {x: 56, y: 56, sx: 1, sy: 1},
  {x: W - 56, y: 56, sx: -1, sy: 1},
  {x: 56, y: H - 56, sx: 1, sy: -1},
  {x: W - 56, y: H - 56, sx: -1, sy: -1},
];
// Риски вдоль левого края; каждая пятая — длиннее.
const TICKS = (() => {
  let d = '';
  for (let y = 440, j = 0; y <= 1480; y += 20, j++) d += `M24 ${y}h${j % 5 === 0 ? 16 : 7}`;
  return d;
})();

// Буквы «собираются» из случайных символов за 0.32 с: детерминированно от времени.
const SCR = '0123456789#/+:';
const hash = (n: number) => {
  const x = Math.sin(n * 12.9898) * 43758.5453;
  return x - Math.floor(x);
};
const scramble = (text: string, local: number, seed: number) => {
  const p = clamp01(local / 0.32);
  const f = Math.floor(local * FPS);
  const n = Math.max(1, text.length - 1);
  return Array.from(text)
    .map((ch, i) => {
      if (ch === ' ' || p >= 0.2 + 0.6 * (i / n)) return ch;
      return SCR[Math.floor(hash(seed + i * 31 + f * 17) * SCR.length)];
    })
    .join('');
};
const pad2 = (n: number) => String(n).padStart(2, '0');

const Hud: React.FC<{t: number; scene: SceneSpec; local: number}> = ({t, scene, local}) => {
  const p = clamp01(t / TOTAL);
  // Углы «щёлкают» на смене сцены: сходятся к рамке за 0.25 с.
  const off = (1 - easeOut(clamp01(local / 0.25))) * 16;
  const op = scene.end ? 1 - easeOut(clamp01(local / 0.8)) : 1;
  const fi = FEATURES.findIndex((f) => f.id === scene.id);
  const counter = fi >= 0 ? `SPROUT — ${pad2(fi + 1)} / ${pad2(FEATURES.length)}` : null;
  const label = FEATURE_LABEL[scene.id] ?? null;
  const labelStyle: React.CSSProperties = {
    position: 'absolute',
    top: 112,
    fontSize: 20,
    fontWeight: 600,
    letterSpacing: '0.12em',
    whiteSpace: 'pre',
    color: 'rgba(255,255,255,0.6)',
    opacity: op,
    filter: `blur(${(1 - clamp01(local / 0.3)) * 3}px)`,
  };
  return (
    <>
      <svg width={W} height={H} style={{position: 'absolute', left: 0, top: 0, opacity: op, overflow: 'visible'}}>
        <rect x={0} y={0} width={W} height={2} fill="rgba(255,255,255,0.12)" />
        <rect x={0} y={0} width={W * p} height={2} fill="rgba(255,255,255,0.85)" />
        <path d={TICKS} stroke="rgba(255,255,255,0.35)" strokeWidth={1.5} fill="none" />
        <rect x={22} y={440 + p * 1040 - 1} width={22} height={2} fill="#ffffff" />
        {CORNERS.map((c) => (
          <path
            key={`${c.x}-${c.y}`}
            d={`M${c.x + c.sx * 44} ${c.y} H${c.x} V${c.y + c.sy * 44}`}
            transform={`translate(${c.sx * off} ${c.sy * off})`}
            stroke="rgba(255,255,255,0.5)"
            strokeWidth={1.5}
            fill="none"
          />
        ))}
      </svg>
      {counter && (
        <div style={{...labelStyle, left: HX, fontFamily: MONO}}>{scramble(counter, local, 11)}</div>
      )}
      {label && (
        <div style={{...labelStyle, right: HX, fontFamily: FONT, textTransform: 'uppercase'}}>{scramble(label, local, 47)}</div>
      )}
    </>
  );
};

// ---------- Финал: логотик из кривых, имя, плейсхолдеры ----------
const LOGO_H = 360;
const LOGO_CY = 800;
const LOGO_TOTAL = 1.6; // секунды на весь логотип (как в Text.tsx)
const LOGO_K = LOGO_H / LOGO_BOX.h;
const LOGO_PAD = LOGO_BOX.stroke / 2;
const LOGO_VW = LOGO_BOX.w + 2 * LOGO_PAD;

const poly = (pts: number[][], closed: boolean) =>
  pts.map((p, i) => `${i ? 'L' : 'M'}${p[0]} ${p[1]}`).join(' ') + (closed ? ' Z' : '');

// Штрих начинается у основания листа — рост идёт снизу вверх.
const bottomUp = (pts: number[][], closed: boolean) => {
  if (!closed) return pts[0][1] < pts[pts.length - 1][1] ? [...pts].reverse() : pts;
  let mi = 0;
  pts.forEach((p, i) => {
    if (p[1] > pts[mi][1]) mi = i;
  });
  return [...pts.slice(mi), ...pts.slice(0, mi)];
};

const logoShapes = (local: number) =>
  LOGO_PARTS.map((part, i) => {
    const raw = clamp01((local / LOGO_TOTAL - i * M.logoLag) / (1 - (LOGO_PARTS.length - 1) * M.logoLag));
    const g = easeOut(raw);
    return (
      <g key={i}>
        {part.leaves.map((li) => {
          const L = LOGO_LEAVES[li];
          return (
            <path
              key={li}
              d={poly(bottomUp(L.pts, L.closed), L.closed)}
              fill="none"
              stroke={COL.green}
              strokeWidth={LOGO_BOX.stroke}
              strokeLinejoin="miter"
              strokeLinecap="butt"
              strokeMiterlimit={4}
              pathLength={1}
              strokeDasharray="1 1"
              strokeDashoffset={1 - g}
            />
          );
        })}
        {part.drops.map((di) => {
          const pts = LOGO_DROPS[di];
          const cx = pts.reduce((a, p) => a + p[0], 0) / pts.length;
          const cy = pts.reduce((a, p) => a + p[1], 0) / pts.length;
          const sc = M.logoScale + (1 - M.logoScale) * g + 0.06 * Math.sin(Math.PI * g);
          return (
            <path
              key={di}
              d={poly(pts, true)}
              fill={COL.water}
              opacity={clamp01(raw * 2.5)}
              transform={`translate(${cx} ${cy}) scale(${sc}) translate(${-cx} ${-cy})`}
            />
          );
        })}
      </g>
    );
  });

const EndCard: React.FC<{local: number}> = ({local}) => {
  const word = sui((local - 1.2) * FPS, FPS, 0.6, 0.15);
  const tag = sui((local - 1.55) * FPS, FPS, 0.6, 0.15);
  const pill = sui((local - 1.9) * FPS, FPS, 0.6, 0.2);
  const rise = (p: number, d: number, a = 1): React.CSSProperties => ({
    opacity: clamp01(p * 1.4) * a,
    transform: `translateY(${(1 - p) * d}px)`,
    filter: `blur(${(1 - clamp01(p)) * 12}px)`,
  });
  const glow = 0.75 + 0.15 * Math.sin(local * 2);
  return (
    <>
      <svg
        width={LOGO_VW * LOGO_K}
        height={LOGO_H}
        viewBox={`${-LOGO_PAD} 0 ${LOGO_VW} ${LOGO_BOX.h}`}
        style={{position: 'absolute', left: W / 2 - (LOGO_VW * LOGO_K) / 2, top: LOGO_CY - LOGO_H / 2, overflow: 'visible'}}
      >
        <defs>
          <filter id="ovGlow" x="-50%" y="-30%" width="200%" height="160%">
            <feGaussianBlur stdDeviation="2.4" />
          </filter>
          <filter id="ovGlowWide" x="-80%" y="-40%" width="260%" height="180%">
            <feGaussianBlur stdDeviation="7" />
          </filter>
        </defs>
        <g filter="url(#ovGlowWide)" opacity={0.55 * glow}>
          {logoShapes(local)}
        </g>
        <g filter="url(#ovGlow)" opacity={0.9 * glow}>
          {logoShapes(local)}
        </g>
        <g>{logoShapes(local)}</g>
      </svg>
      <div
        style={{
          position: 'absolute',
          left: 0,
          top: 1010,
          width: W,
          textAlign: 'center',
          fontFamily: FONT,
          fontWeight: 800,
          fontSize: 120,
          lineHeight: 1,
          letterSpacing: '-0.03em',
          color: '#ffffff',
          ...rise(word, 26),
        }}
      >
        Sprout
      </div>
      <div
        style={{
          position: 'absolute',
          left: 0,
          top: 1144,
          width: W,
          textAlign: 'center',
          fontFamily: FONT,
          fontWeight: 600,
          fontSize: 40,
          lineHeight: 1.2,
          color: '#ffffff',
          ...rise(tag, 20, 0.6),
        }}
      >
        [слоган]
      </div>
      <div style={{position: 'absolute', left: 0, top: 1238, width: W, display: 'flex', justifyContent: 'center'}}>
        <div
          style={{
            padding: '20px 40px',
            borderRadius: 999,
            border: '1.5px solid rgba(255,255,255,0.5)',
            fontFamily: FONT,
            fontWeight: 600,
            fontSize: 32,
            lineHeight: 1.2,
            color: '#ffffff',
            whiteSpace: 'nowrap',
            ...rise(pill, 14),
          }}
        >
          [плашка App Store] · [ссылка]
        </div>
      </div>
    </>
  );
};

// ---------- Слой ----------
export const Overlay: React.FC<{time: number}> = ({time}) => {
  const t = Math.max(0, time);
  const {scene, local} = sceneAt(t);
  return (
    <div style={{position: 'absolute', left: 0, top: 0, width: W, height: H, overflow: 'hidden'}}>
      <Hud t={t} scene={scene} local={local} />
      {scene.end ? (
        <EndCard local={local} />
      ) : scene.id === 'hook' ? (
        <Hook local={local} dur={scene.dur} />
      ) : scene.word ? (
        <Headline lines={scene.word.split('\n')} sub={scene.sub} local={local} dur={scene.dur} />
      ) : null}
    </div>
  );
};

export const OverlayPreview: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  return (
    <AbsoluteFill style={{background: 'radial-gradient(ellipse at 50% 40%, #0b0d0c 0%, #000 100%)'}}>
      <Overlay time={frame / fps} />
    </AbsoluteFill>
  );
};
