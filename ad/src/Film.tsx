import React from 'react';
import {AbsoluteFill, staticFile, useCurrentFrame, useVideoConfig} from 'remotion';
import {Collapse, Flip, Pattern, Wave} from './parts/Pattern';
import {Phone, Pose, SCREEN, ScreenCue, TapCue} from './parts/Phone';
import {Plant, PlantKey, track} from './parts/Plant';
import {Caption, EndCard} from './parts/Text';
import {C, FONT, RGB, clamp01, rgb, sui} from './tokens';

export type Layout = {
  W: number;
  H: number;
  kind: 'tall' | 'square' | 'wide';
  base: number; // px на pt у телефона
  k: number; // px на pt у узора
  phone: {x: number; y: number};
  plant: {x: number; y: number; h: number};
  cap: {x: number; y: number; w: number; size: number; align: 'left' | 'center'};
  word: {x: number; y: number; w: number; size: number; align: 'left' | 'center'};
  logoH: number;
  end: {cx: number; cy: number; horizontal: boolean};
};

export const layoutFor = (W: number, H: number): Layout => {
  if (W === H)
    return {
      W,
      H,
      kind: 'square',
      base: 0.84,
      k: 1.05,
      phone: {x: 810, y: 600},
      plant: {x: 300, y: 1090, h: 700},
      cap: {x: 56, y: 70, w: 540, size: 62, align: 'left'},
      word: {x: 56, y: 110, w: 540, size: 140, align: 'left'},
      logoH: 270,
      end: {cx: 540, cy: 480, horizontal: false},
    };
  if (W > H)
    return {
      W,
      H,
      kind: 'wide',
      base: 0.9,
      k: 1.05,
      phone: {x: 1400, y: 590},
      plant: {x: 1010, y: 1110, h: 860},
      cap: {x: 120, y: 300, w: 760, size: 86, align: 'left'},
      word: {x: 120, y: 330, w: 900, size: 190, align: 'left'},
      logoH: 300,
      end: {cx: 900, cy: 540, horizontal: true},
    };
  return {
    W,
    H,
    kind: 'tall',
    base: 1.3,
    k: 1.3,
    phone: {x: 660, y: 1190},
    plant: {x: 250, y: 1900, h: 1400},
    cap: {x: 70, y: 200, w: 940, size: 82, align: 'center'},
    word: {x: 60, y: 190, w: 960, size: 210, align: 'center'},
    logoH: 380,
    end: {cx: 540, cy: 900, horizontal: false},
  };
};

export type Ctx = {L: Layout; t: number; fps: number; dark: boolean; T: number};

export type Scene = {
  id: string;
  dur: number;
  caption?: string;
  sub?: string;
  screens?: ScreenCue[]; // время — от начала сцены
  taps?: (TapCue & {world?: boolean})[];
  pose?: (t: number, L: Layout) => Pose;
  plant?: PlantKey[];
  flip?: {at: number; to: 'dark' | 'light'};
  phoneHidden?: boolean;
  noWave?: boolean;
  behind?: (c: Ctx) => React.ReactNode; // между растением и телефоном
  front?: (c: Ctx) => React.ReactNode; // поверх телефона
  above?: (c: Ctx) => React.ReactNode; // в объёме над экраном
  end?: boolean;
};

// Поза относительно места телефона в раскладке; сдвиги — в «высотах телефона».
export const at = (L: Layout, o: Partial<Pose> & {dx?: number; dy?: number} = {}): Pose => ({
  x: L.phone.x + (o.dx ?? 0) * SCREEN.h * L.base,
  y: L.phone.y + (o.dy ?? 0) * SCREEN.h * L.base,
  s: o.s ?? 1,
  rx: o.rx ?? 0,
  ry: o.ry ?? 0,
  rz: o.rz ?? 0,
});

const lerpPose = (a: Pose, b: Pose, p: number): Pose => ({
  x: a.x + (b.x - a.x) * p,
  y: a.y + (b.y - a.y) * p,
  s: a.s + (b.s - a.s) * p,
  rx: a.rx + (b.rx - a.rx) * p,
  ry: a.ry + (b.ry - a.ry) * p,
  rz: a.rz + (b.rz - a.rz) * p,
});

export const starts = (scenes: Scene[]) => {
  const out: number[] = [];
  let acc = 0;
  for (const s of scenes) {
    out.push(acc);
    acc += s.dur;
  }
  return {starts: out, total: acc};
};

export const Film: React.FC<{scenes: Scene[]; dark?: boolean; plantBase?: PlantKey[]}> = ({scenes, dark = false, plantBase = []}) => {
  const frame = useCurrentFrame();
  const {fps, width: W, height: H} = useVideoConfig();
  const L = layoutFor(W, H);
  const T = frame / fps;
  const {starts: st} = starts(scenes);
  let si = 0;
  for (let i = 0; i < scenes.length; i++) if (st[i] <= T) si = i;
  const scene = scenes[si];
  const lt = T - st[si];

  // Поза: в начале сцены перетекает из конца прошлой.
  const poseOf = (i: number, t: number): Pose => (scenes[i].pose ? scenes[i].pose!(t, L) : at(L));
  let pose = poseOf(si, lt);
  if (si > 0) {
    const prevEnd = poseOf(si - 1, scenes[si - 1].dur);
    const p = sui(lt * fps, fps, 0.75, 0.12);
    pose = lerpPose(prevEnd, pose, p);
  }

  // Всё глобальное: кадры экрана, касания, волны, растение, перекраска.
  const cues: ScreenCue[] = [];
  const taps: TapCue[] = [];
  const waves: Wave[] = [];
  const flips: Flip[] = [];
  const plantKeys: PlantKey[] = [...plantBase];
  let collapse: Collapse | undefined;
  scenes.forEach((s, i) => {
    const t0 = st[i];
    s.screens?.forEach((c) => cues.push({...c, at: c.at + t0}));
    s.plant?.forEach((k) => plantKeys.push({...k, at: k.at + t0}));
    if (i > 0 && !s.noWave && !s.end) {
      const ps = poseOf(i, 0);
      waves.push({t0, x: ps.x, y: ps.y, strength: 0.6});
    }
    s.taps?.forEach((tp) => {
      taps.push({...tp, at: tp.at + t0});
      if (tp.world) {
        const ps = poseOf(i, tp.at);
        waves.push({
          t0: tp.at + t0 + 0.15,
          x: ps.x + (tp.x - SCREEN.w / 2) * L.base * ps.s,
          y: ps.y + (tp.y - SCREEN.h / 2) * L.base * ps.s,
          strength: 1,
        });
      }
    });
    if (s.flip) flips.push({t0: t0 + s.flip.at, x: L.phone.x, y: L.phone.y, to: s.flip.to});
    if (s.end) collapse = {t0: t0 + 0.1, x: L.end.cx, y: L.end.cy, seconds: 1.4};
  });
  cues.sort((a, b) => a.at - b.at);
  plantKeys.sort((a, b) => a.at - b.at);

  // Тёмная ли сейчас тема у места телефона — для цвета подписей.
  let isDark = dark;
  for (const f of flips) if (T > f.t0 + 0.6) isDark = f.to === 'dark';
  const ink: RGB = isDark ? C.inkDark : C.inkLight;

  const health = track(plantKeys, 'health', T, fps, 0.9, 0.28);
  const bloom = track(plantKeys, 'bloom', T, fps, 1.6, 0);
  const ctx: Ctx = {L, t: lt, fps, dark: isDark, T};

  const endT = scene.end ? lt : -1;
  const phoneGone = scene.end ? clamp01(lt / 0.7) : 0;
  const endBg = scene.end ? clamp01((lt - 0.9) / 0.6) : 0;
  const plantOut = scene.end ? clamp01(lt / 0.6) : 0;

  if (scene.end) {
    pose = {...pose, x: pose.x + (L.end.cx - pose.x) * phoneGone, y: pose.y + (L.end.cy - pose.y) * phoneGone, s: pose.s * (1 - 0.92 * phoneGone)};
  }

  return (
    <AbsoluteFill style={{fontFamily: FONT}}>
      <Pattern w={W} h={H} k={L.k} t={T} waves={waves} flips={flips} collapse={collapse} base={dark ? 'dark' : 'light'} />
      {endBg > 0 && (
        <AbsoluteFill
          style={{
            background: rgb(isDark ? C.welcomeDark : C.welcomeLight),
            clipPath: `circle(${endBg * Math.hypot(W, H)}px at ${L.end.cx}px ${L.end.cy}px)`,
          }}
        />
      )}
      <div style={{position: 'absolute', inset: 0, opacity: 1 - plantOut, transform: `translateY(${plantOut * 80}px)`}}>
        <Plant x={L.plant.x} y={L.plant.y} h={L.plant.h} health={health} bloom={bloom} t={T} dark={isDark} />
      </div>
      {L.kind === 'tall' && (
        <AbsoluteFill
          style={{
            background: `linear-gradient(180deg, ${rgb(isDark ? C.bgDark : C.bgLight, 0.92)} 0%, ${rgb(isDark ? C.bgDark : C.bgLight, 0.7)} 22%, ${rgb(isDark ? C.bgDark : C.bgLight, 0)} 34%)`,
            opacity: 1 - endBg,
          }}
        />
      )}
      {L.kind !== 'tall' && (
        <AbsoluteFill
          style={{
            background: `linear-gradient(90deg, ${rgb(isDark ? C.bgDark : C.bgLight, 0.9)} 0%, ${rgb(isDark ? C.bgDark : C.bgLight, 0.6)} 38%, ${rgb(isDark ? C.bgDark : C.bgLight, 0)} 55%)`,
            opacity: 1 - endBg,
          }}
        />
      )}
      {scene.behind?.(ctx)}
      {!scene.phoneHidden && phoneGone < 1 && (
        <div style={{opacity: 1 - phoneGone}}>
          <Phone
            pose={pose}
            base={L.base}
            cues={cues}
            taps={taps}
            t={T}
            fps={fps}
            above={scene.above?.(ctx)}
          />
        </div>
      )}
      {scene.front?.(ctx)}
      {scene.caption && (
        <Caption
          text={scene.caption}
          sub={scene.sub}
          t={lt}
          dur={scene.dur}
          fps={fps}
          x={L.cap.x}
          y={L.cap.y}
          w={L.cap.w}
          size={L.cap.size}
          align={L.cap.align}
          ink={ink}
        />
      )}
      {scene.end && (
        <EndCard
          t={endT - 0.9}
          fps={fps}
          w={W}
          h={H}
          cx={L.end.cx}
          cy={L.end.cy}
          logoH={L.logoH}
          dark={isDark}
          horizontal={L.end.horizontal}
        />
      )}
    </AbsoluteFill>
  );
};

export const watchSrc = staticFile('scr/watch.jpg');
