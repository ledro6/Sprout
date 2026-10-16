import React from 'react';
import {Img, staticFile} from 'remotion';
import {C, clamp01, easeOut, rgb, sui} from '../tokens';

// Экран iPhone в макете — 402×874 pt.
export const SCREEN = {w: 402, h: 874, r: 55};

export type Pose = {x: number; y: number; s: number; rx: number; ry: number; rz: number};

export type ScreenCue = {
  at: number; // секунды, глобально
  src: string;
  kind?: 'blur' | 'zoom' | 'slide' | 'cut';
  ox?: number; // точка, откуда разворачивается карточка (pt)
  oy?: number;
  dur?: number;
};

export type TapCue = {at: number; x: number; y: number; wave?: boolean};

const src = (name: string) => staticFile(`scr/${name}.jpg`);

// Экран: очередь кадров из макета и переходы приложения — размытие, разворачивание
// карточки, листание комнат.
const Screens: React.FC<{cues: ScreenCue[]; t: number; fps: number; s: number}> = ({cues, t, fps, s}) => {
  const w = SCREEN.w * s;
  const h = SCREEN.h * s;
  let i = 0;
  for (let k = 0; k < cues.length; k++) if (cues[k].at <= t) i = k;
  const cur = cues[i];
  const prev = i > 0 ? cues[i - 1] : undefined;
  const lt = t - cur.at;
  const kind = cur.kind ?? 'blur';
  const layer = (name: string, style: React.CSSProperties, key: string) => (
    <Img key={key} src={src(name)} style={{position: 'absolute', left: 0, top: 0, width: w, height: h, ...style}} />
  );
  const out: React.ReactNode[] = [];
  if (prev && lt < 0.9) {
    if (kind === 'blur') {
      const p = clamp01(lt / 0.28);
      out.push(layer(prev.src, {opacity: 1 - p, filter: `blur(${10 * p}px)`}, 'p'));
    } else if (kind === 'zoom') {
      const p = sui(lt * fps, fps, 0.5, 0.12);
      out.push(layer(prev.src, {transform: `scale(${1 - 0.06 * p})`, filter: `brightness(${1 - 0.25 * p})`}, 'p'));
    } else if (kind === 'slide') {
      const p = sui(lt * fps, fps, 0.55, 0.05);
      out.push(layer(prev.src, {transform: `translateX(${-w * p}px)`}, 'p'));
    }
  }
  if (kind === 'blur' && prev) {
    const p = clamp01(lt / 0.42);
    out.push(layer(cur.src, {opacity: easeOut(p), filter: `blur(${12 * (1 - easeOut(p))}px)`}, 'c'));
  } else if (kind === 'zoom' && prev) {
    const p = sui(lt * fps, fps, 0.5, 0.12);
    const ox = (cur.ox ?? SCREEN.w / 2) * s;
    const oy = (cur.oy ?? SCREEN.h / 2) * s;
    const k = 0.32 + 0.68 * p;
    out.push(
      <div
        key="c"
        style={{
          position: 'absolute',
          inset: 0,
          overflow: 'hidden',
          borderRadius: (1 - p) * 26 * s,
          transformOrigin: `${ox}px ${oy}px`,
          transform: `scale(${k})`,
          opacity: clamp01(p * 3),
        }}
      >
        {layer(cur.src, {}, 'ci')}
      </div>,
    );
  } else if (kind === 'slide' && prev) {
    const p = sui(lt * fps, fps, 0.55, 0.05);
    out.push(layer(cur.src, {transform: `translateX(${w * (1 - p)}px)`}, 'c'));
  } else {
    out.push(layer(cur.src, {}, 'c'));
  }
  return <>{out}</>;
};

// Касание пальца: светлый круг с кольцом и синяя волна по экрану.
const Taps: React.FC<{taps: TapCue[]; t: number; s: number}> = ({taps, t, s}) => (
  <>
    {taps
      .filter((tp) => t >= tp.at - 0.25 && t < tp.at + 2.6)
      .map((tp, i) => {
        const lt = t - tp.at;
        const press = lt < 0 ? clamp01((lt + 0.25) / 0.25) : clamp01(1 - lt / 0.35);
        const ring = clamp01(lt / 0.5);
        const wave = clamp01(lt / 2.4);
        return (
          <React.Fragment key={i}>
            {tp.wave && lt > 0 && (
              <div
                style={{
                  position: 'absolute',
                  left: tp.x * s,
                  top: tp.y * s,
                  width: 0,
                  height: 0,
                }}
              >
                <div
                  style={{
                    position: 'absolute',
                    left: -1100 * s * wave,
                    top: -1100 * s * wave,
                    width: 2200 * s * wave,
                    height: 2200 * s * wave,
                    borderRadius: '50%',
                    background: `radial-gradient(circle, rgba(0,122,255,0) 52%, ${rgb(C.waveBlue, 0.22 * (1 - wave))} 64%, rgba(0,122,255,0) 72%)`,
                    mixBlendMode: 'multiply',
                  }}
                />
              </div>
            )}
            <div
              style={{
                position: 'absolute',
                left: tp.x * s - 26 * s,
                top: tp.y * s - 26 * s,
                width: 52 * s,
                height: 52 * s,
                borderRadius: '50%',
                background: `rgba(255,255,255,${0.55 * press})`,
                boxShadow: `0 0 ${18 * s}px rgba(0,0,0,${0.18 * press})`,
                transform: `scale(${0.8 + 0.2 * press})`,
              }}
            />
            {lt > 0 && (
              <div
                style={{
                  position: 'absolute',
                  left: tp.x * s - 26 * s,
                  top: tp.y * s - 26 * s,
                  width: 52 * s,
                  height: 52 * s,
                  borderRadius: '50%',
                  border: `${2.5 * s}px solid rgba(255,255,255,${0.9 * (1 - ring)})`,
                  transform: `scale(${1 + 1.6 * easeOut(ring)})`,
                }}
              />
            )}
          </React.Fragment>
        );
      })}
  </>
);

type PhoneProps = {
  pose: Pose;
  base: number; // px на pt при s = 1
  cues: ScreenCue[];
  taps: TapCue[];
  t: number;
  fps: number;
  overlay?: React.ReactNode; // поверх экрана, в его плоскости (pt × s)
  above?: React.ReactNode; // над экраном, в объёме
  shadow?: boolean;
  dim?: number;
};

// Объёмный iPhone: корпус — стопка скруглённых срезов (толщина), стекло с бликом,
// экран — настоящие кадры из Figma.
export const Phone: React.FC<PhoneProps> = ({pose, base, cues, taps, t, fps, overlay, above, shadow = true, dim = 0}) => {
  const s = base;
  const w = SCREEN.w * s;
  const h = SCREEN.h * s;
  const bezel = 5.5 * s;
  const frame = 3.4 * s;
  const bw = w + 2 * (bezel + frame);
  const bh = h + 2 * (bezel + frame);
  const br = (SCREEN.r + 9) * s;
  const depth = 30 * s;
  const slices = 22;
  const glare = 0.5 + pose.ry / 70 + pose.rx / 140;

  const sliceEls = Array.from({length: slices}, (_, i) => {
    const z = -depth + (depth * i) / (slices - 1);
    const shade = 0.62 + 0.38 * Math.sin((Math.PI * i) / (slices - 1));
    return (
      <div
        key={i}
        style={{
          position: 'absolute',
          left: 0,
          top: 0,
          width: bw,
          height: bh,
          borderRadius: br,
          background: `linear-gradient(135deg, rgb(${206 * shade},${202 * shade},${196 * shade}), rgb(${150 * shade},${146 * shade},${141 * shade}) 55%, rgb(${190 * shade},${186 * shade},${180 * shade}))`,
          transform: `translateZ(${z}px)`,
        }}
      />
    );
  });

  return (
    <>
      {shadow && (
        <div
          style={{
            position: 'absolute',
            left: pose.x - bw * pose.s * 0.5,
            top: pose.y + bh * pose.s * 0.36 * Math.cos((pose.rx * Math.PI) / 180) + 30 * s,
            width: bw * pose.s,
            height: 120 * s * pose.s,
            borderRadius: '50%',
            background: 'rgba(20,40,25,0.32)',
            filter: `blur(${40 * s}px)`,
            transform: `scaleX(${1 + Math.abs(pose.ry) / 90})`,
          }}
        />
      )}
      <div
        style={{
          position: 'absolute',
          left: pose.x - bw / 2,
          top: pose.y - bh / 2,
          width: bw,
          height: bh,
          perspective: 2600,
          perspectiveOrigin: '50% 40%',
        }}
      >
        <div
          style={{
            position: 'absolute',
            inset: 0,
            transformStyle: 'preserve-3d',
            transform: `scale(${pose.s}) rotateX(${pose.rx}deg) rotateY(${pose.ry}deg) rotateZ(${pose.rz}deg)`,
          }}
        >
          {/* Задняя крышка */}
          <div
            style={{
              position: 'absolute',
              inset: 0,
              borderRadius: br,
              background: 'linear-gradient(160deg, #b9b4ad, #8f8a84)',
              transform: `translateZ(${-depth - 0.5}px) rotateY(180deg)`,
            }}
          />
          {sliceEls}
          {/* Кнопки сбоку */}
          {[
            {top: 0.2, len: 0.055},
            {top: 0.29, len: 0.09},
            {top: 0.4, len: 0.09},
          ].map((b, i) => (
            <div
              key={i}
              style={{
                position: 'absolute',
                left: -2.2 * s,
                top: bh * b.top,
                width: 3 * s,
                height: bh * b.len,
                borderRadius: 2 * s,
                background: '#9a958f',
                transform: `translateZ(${-depth / 2}px)`,
              }}
            />
          ))}
          {/* Лицевая сторона: рамка, стекло, экран */}
          <div
            style={{
              position: 'absolute',
              left: frame,
              top: frame,
              width: bw - 2 * frame,
              height: bh - 2 * frame,
              borderRadius: br - frame,
              background: '#050505',
              transform: 'translateZ(0.6px)',
              boxShadow: `inset 0 0 0 ${0.8 * s}px rgba(255,255,255,0.12)`,
            }}
          >
            <div
              style={{
                position: 'absolute',
                left: bezel,
                top: bezel,
                width: w,
                height: h,
                borderRadius: SCREEN.r * s,
                overflow: 'hidden',
                background: '#fff',
              }}
            >
              <Screens cues={cues} t={t} fps={fps} s={s} />
              {overlay}
              <Taps taps={taps} t={t} s={s} />
              {dim > 0 && <div style={{position: 'absolute', inset: 0, background: `rgba(0,0,0,${dim})`}} />}
              <div
                style={{
                  position: 'absolute',
                  inset: 0,
                  background: `linear-gradient(118deg, rgba(255,255,255,0) ${glare * 100 - 22}%, rgba(255,255,255,0.16) ${glare * 100}%, rgba(255,255,255,0) ${glare * 100 + 18}%)`,
                  pointerEvents: 'none',
                }}
              />
            </div>
          </div>
          {above && (
            <div
              style={{
                position: 'absolute',
                left: frame + bezel,
                top: frame + bezel,
                width: w,
                height: h,
                transformStyle: 'preserve-3d',
                transform: 'translateZ(1px)',
              }}
            >
              {above}
            </div>
          )}
        </div>
      </div>
    </>
  );
};
