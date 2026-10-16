import React from 'react';
import {Img} from 'remotion';
import {C, FONT, LOGO_BOX, LOGO_DROPS, LOGO_LEAVES, LOGO_PARTS, M, RGB, clamp01, easeOut, rgb, sui} from '../tokens';

// Подпись проступает из размытия и поднимается пружиной (Motion.enter), уходит
// тем же размытием вверх.
export const Caption: React.FC<{
  text: string;
  sub?: string;
  t: number; // локальное время подписи
  dur: number;
  fps: number;
  x: number;
  y: number;
  w: number;
  size: number;
  align?: 'left' | 'center';
  ink: RGB;
}> = ({text, sub, t, dur, fps, x, y, w, size, align = 'center', ink}) => {
  if (t < 0 || t > dur) return null;
  const inP = sui(t * fps, fps, 0.5, 0.2);
  const outP = clamp01((t - (dur - 0.3)) / 0.3);
  const blur = M.textBlur * 2 * (1 - clamp01(t / 0.35)) + 14 * outP;
  return (
    <div
      style={{
        position: 'absolute',
        left: x,
        top: y,
        width: w,
        textAlign: align,
        fontFamily: FONT,
        color: rgb(ink),
        transform: `translateY(${(1 - inP) * 34 - outP * 30}px)`,
        opacity: clamp01(t / 0.25) * (1 - outP),
        filter: `blur(${blur}px)`,
      }}
    >
      <div style={{fontSize: size, fontWeight: 800, lineHeight: 1.05, letterSpacing: -size * 0.025, whiteSpace: 'pre-line'}}>
        {text}
      </div>
      {sub && (
        <div
          style={{
            marginTop: size * 0.32,
            fontSize: size * 0.44,
            fontWeight: 500,
            lineHeight: 1.25,
            opacity: 0.62,
            whiteSpace: 'pre-line',
          }}
        >
          {sub}
        </div>
      )}
    </div>
  );
};

const poly = (pts: number[][], closed: boolean) =>
  pts.map((p, i) => `${i ? 'L' : 'M'}${p[0]} ${p[1]}`).join(' ') + (closed ? ' Z' : '');
const perim = (pts: number[][], closed: boolean) => {
  let l = 0;
  for (let i = 1; i < pts.length; i++) l += Math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]);
  if (closed) l += Math.hypot(pts[0][0] - pts[pts.length - 1][0], pts[0][1] - pts[pts.length - 1][1]);
  return l;
};

// Логотип кривыми: листья прорисовываются линией снизу вверх, как растёт росток
// (порядок частей и запаздывание — SproutLogo), капли проступают последними.
export const Logo: React.FC<{t: number; height: number; x: number; y: number}> = ({t, height, x, y}) => {
  const pad = LOGO_BOX.stroke / 2;
  const vw = LOGO_BOX.w + 2 * pad;
  const k = height / LOGO_BOX.h;
  const total = 1.6; // секунды на весь логотип
  const parts = LOGO_PARTS.map((part, i) => {
    const step = clamp01((t / total - i * M.logoLag) / (1 - (LOGO_PARTS.length - 1) * M.logoLag));
    const g = 1 - Math.pow(1 - step, 3);
    return (
      <g key={i}>
        {part.leaves.map((li) => {
          const L = LOGO_LEAVES[li];
          const len = perim(L.pts, L.closed);
          return (
            <path
              key={li}
              d={poly(L.pts, L.closed)}
              fill="none"
              stroke={rgb(C.green)}
              strokeWidth={LOGO_BOX.stroke}
              strokeLinejoin="miter"
              strokeLinecap="butt"
              strokeMiterlimit={4}
              strokeDasharray={len + 1}
              strokeDashoffset={(len + 1) * (1 - g)}
            />
          );
        })}
        {part.drops.map((di) => {
          const pts = LOGO_DROPS[di];
          const cx = pts.reduce((a, p) => a + p[0], 0) / pts.length;
          const cy = pts.reduce((a, p) => a + p[1], 0) / pts.length;
          const sc = M.logoScale + (1 - M.logoScale) * g;
          return (
            <path
              key={di}
              d={poly(pts, true)}
              fill={rgb(C.water)}
              opacity={g}
              transform={`translate(${cx} ${cy}) scale(${sc}) translate(${-cx} ${-cy})`}
            />
          );
        })}
      </g>
    );
  });
  return (
    <svg
      width={vw * k}
      height={height}
      viewBox={`${-pad} 0 ${vw} ${LOGO_BOX.h}`}
      style={{position: 'absolute', left: x - (vw * k) / 2, top: y - height / 2, overflow: 'visible'}}
    >
      {parts}
    </svg>
  );
};

// Финал: логотип, имя, слоган-плейсхолдер и плашка магазина-плейсхолдер.
export const EndCard: React.FC<{
  t: number;
  fps: number;
  w: number;
  h: number;
  cx: number;
  cy: number;
  logoH: number;
  dark?: boolean;
  horizontal?: boolean;
}> = ({t, fps, w, h, cx, cy, logoH, dark, horizontal}) => {
  if (t < 0) return null;
  const ink = dark ? C.inkDark : C.inkLight;
  const word = sui((t - 1.0) * fps, fps, 0.55, 0.18);
  const tag = sui((t - 1.45) * fps, fps, 0.55, 0.18);
  const badge = sui((t - 1.85) * fps, fps, 0.55, 0.22);
  const size = logoH * 0.42;
  const textX = horizontal ? cx + logoH * 0.45 : cx;
  const logoX = horizontal ? cx - logoH * 0.55 : cx;
  const logoY = horizontal ? cy : cy - logoH * 0.55;
  const textTop = horizontal ? cy - size * 1.1 : cy + logoH * 0.12;
  return (
    <div style={{position: 'absolute', left: 0, top: 0, width: w, height: h}}>
      <Logo t={t} height={logoH} x={logoX} y={logoY} />
      <div
        style={{
          position: 'absolute',
          left: horizontal ? textX : 0,
          width: horizontal ? w - textX : w,
          top: textTop,
          textAlign: horizontal ? 'left' : 'center',
          fontFamily: FONT,
          color: rgb(ink),
        }}
      >
        <div
          style={{
            fontSize: size,
            fontWeight: 800,
            letterSpacing: -size * 0.03,
            opacity: clamp01(word * 1.4),
            filter: `blur(${(1 - clamp01(word)) * 10}px)`,
            transform: `translateY(${(1 - word) * 26}px)`,
          }}
        >
          Sprout
        </div>
        <div
          style={{
            marginTop: size * 0.12,
            fontSize: size * 0.42,
            fontWeight: 600,
            opacity: clamp01(tag) * 0.7,
            filter: `blur(${(1 - clamp01(tag)) * 8}px)`,
            transform: `translateY(${(1 - tag) * 20}px)`,
          }}
        >
          [слоган]
        </div>
        <div
          style={{
            display: 'inline-flex',
            alignItems: 'center',
            gap: size * 0.2,
            marginTop: size * 0.5,
            padding: `${size * 0.2}px ${size * 0.42}px`,
            borderRadius: size * 0.26,
            background: dark ? '#fff' : '#000',
            color: dark ? '#000' : '#fff',
            fontSize: size * 0.34,
            fontWeight: 700,
            opacity: clamp01(badge),
            transform: `scale(${0.85 + 0.15 * badge})`,
          }}
        >
          <span style={{opacity: 0.6, fontWeight: 500}}>[плашка App Store]</span>
          <span>[ссылка]</span>
        </div>
      </div>
    </div>
  );
};

// Apple Watch: корпус и экран из макета («часы_кого полить»).
export const Watch: React.FC<{x: number; y: number; s: number; ry: number; rx: number; t: number; src: string}> = ({
  x,
  y,
  s,
  ry,
  rx,
  t,
  src,
}) => {
  const w = 205 * s;
  const h = 251 * s;
  const pad = 14 * s;
  const depth = 22 * s;
  const tap = clamp01((t - 1.1) / 0.3) * (1 - clamp01((t - 1.5) / 0.3));
  return (
    <div style={{position: 'absolute', left: x - (w + 2 * pad) / 2, top: y - (h + 2 * pad) / 2, perspective: 2000}}>
      <div
        style={{
          position: 'relative',
          width: w + 2 * pad,
          height: h + 2 * pad,
          transformStyle: 'preserve-3d',
          transform: `rotateX(${rx}deg) rotateY(${ry}deg)`,
        }}
      >
        {/* Ремешок */}
        <div
          style={{
            position: 'absolute',
            left: pad + w * 0.16,
            top: -h * 0.75,
            width: w * 0.68,
            height: h * 2.5 + 2 * pad,
            borderRadius: 40 * s,
            background: 'linear-gradient(90deg,#3b6f45,#4f8a5a 50%,#3b6f45)',
            transform: `translateZ(${-depth - 3}px)`,
          }}
        />
        {Array.from({length: 12}, (_, i) => (
          <div
            key={i}
            style={{
              position: 'absolute',
              inset: 0,
              borderRadius: 58 * s,
              background: `rgb(${150 + i * 6},${147 + i * 6},${142 + i * 6})`,
              transform: `translateZ(${-depth + (depth * i) / 11}px)`,
            }}
          />
        ))}
        <div
          style={{
            position: 'absolute',
            right: -7 * s,
            top: h * 0.28,
            width: 12 * s,
            height: 34 * s,
            borderRadius: 5 * s,
            background: '#b5b0aa',
            transform: `translateZ(${-depth / 2}px)`,
          }}
        />
        <div
          style={{
            position: 'absolute',
            left: pad * 0.55,
            top: pad * 0.55,
            right: pad * 0.55,
            bottom: pad * 0.55,
            borderRadius: 50 * s,
            background: '#000',
            transform: 'translateZ(0.6px)',
            overflow: 'hidden',
          }}
        >
          <Img src={src} style={{position: 'absolute', left: pad * 0.45, top: pad * 0.45, width: w, height: h}} />
          <div
            style={{
              position: 'absolute',
              left: '50%',
              top: '62%',
              width: 60 * s,
              height: 60 * s,
              marginLeft: -30 * s,
              borderRadius: '50%',
              background: `rgba(255,255,255,${0.35 * tap})`,
              transform: `scale(${0.6 + tap})`,
            }}
          />
        </div>
      </div>
    </div>
  );
};

export const fadeIn = (t: number, d = 0.4) => easeOut(t / d);
