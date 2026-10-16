// iPhone и Apple Watch для 3D-ролика: титановый корпус, экран-шейдер, стекло.
import React, {useEffect, useMemo, useState} from 'react';
import * as THREE from 'three';
import {Environment, Lightformer, RoundedBox} from '@react-three/drei';
import {useThree} from '@react-three/fiber';
import {ThreeCanvas} from '@remotion/three';
import {AbsoluteFill, continueRender, delayRender, useCurrentFrame, useVideoConfig} from 'remotion';
import {GLOBAL_SCREENS, GLOBAL_TAPS, H, PHONE, ScreenName, ScreenCue, TapCue, W, useScreenTextures} from './shared';
import {faceShape, ribbonGeometry, roundedSlab} from './Phone3D.geom';
import {TAP_SLOTS, makeScreenMaterial, screenUniforms, type ScreenUniforms} from './Phone3D.shader';

// Длительность перехода между экранами, с.
const TR = 0.4;
// Длительность волны касания, с (должна совпадать с шейдером).
const WAVE_LIFE = 2.4;
const KIND = {cut: 0, blur: 1, slide: 2, zoom: 3} as const;

const clamp01 = (x: number) => Math.min(1, Math.max(0, x));

// ---------- Общие материалы ----------
const makeMaterials = () => {
  const titanium = new THREE.MeshPhysicalMaterial({
    color: '#b7b1a6',
    metalness: 1,
    roughness: 0.28,
    anisotropy: 0.35,
    envMapIntensity: 1.1,
  });
  const black = new THREE.MeshPhysicalMaterial({color: '#050505', roughness: 0.25, metalness: 0, clearcoat: 0.5, clearcoatRoughness: 0.2});
  const backGlass = new THREE.MeshPhysicalMaterial({
    color: '#8c867d',
    roughness: 0.2,
    metalness: 0,
    clearcoat: 0.6,
    clearcoatRoughness: 0.1,
  });
  // Стекло только добавляет отражения (аддитивно): UI не темнеет.
  const glass = new THREE.MeshPhysicalMaterial({
    color: '#000000',
    roughness: 0.03,
    metalness: 0,
    clearcoat: 0.6,
    clearcoatRoughness: 0.06,
    transparent: true,
    opacity: 1,
    blending: THREE.AdditiveBlending,
    depthWrite: false,
    envMapIntensity: 0.5,
  });
  const lensGlass = new THREE.MeshPhysicalMaterial({color: '#07080c', roughness: 0.05, metalness: 0.2, clearcoat: 1, clearcoatRoughness: 0.02});
  const flash = new THREE.MeshPhysicalMaterial({color: '#e9dcc0', roughness: 0.2, metalness: 0});
  return {titanium, black, backGlass, glass, lensGlass, flash};
};

// ---------- Состояние экрана по времени ----------
type Cue = {at: number; src: ScreenName; kind: 'blur' | 'zoom' | 'slide' | 'cut'};

const applyCues = (u: ScreenUniforms, cues: Cue[], textures: Record<ScreenName, THREE.Texture>, time: number) => {
  let i = -1;
  for (let k = 0; k < cues.length; k++) {
    if (cues[k].at <= time) i = k;
    else break;
  }
  if (i < 0) i = 0;
  const cur = cues[i];
  const prev = i > 0 ? cues[i - 1] : cur;
  const age = time - cur.at;
  const tr = i > 0 && age < TR && cur.kind !== 'cut';
  u.tB.value = textures[cur.src];
  u.tA.value = tr ? textures[prev.src] : textures[cur.src];
  u.uKind.value = tr ? KIND[cur.kind] : 0;
  u.uP.value = tr ? clamp01(age / TR) : 1;
  u.uBlur.value = 0.03;
};

const applyTaps = (u: ScreenUniforms, taps: TapCue[], time: number) => {
  let n = 0;
  for (const t of taps) {
    const age = time - t.at;
    if (age < 0 || age >= WAVE_LIFE + 0.1) continue;
    if (n >= TAP_SLOTS) break;
    u.uTaps.value[n].set(t.x, t.y, age, t.water ? 1 : 0);
    n++;
  }
  u.uTapN.value = n;
};

// ---------- iPhone ----------
const BEZEL = 0.0125; // рамка экрана, единицы сцены
const BODY_R = 0.108; // внешний радиус скругления корпуса
const EDGE = 0.022; // фаска по кромке

const buildPhoneGeo = () => {
  const {width: w, height: h, depth: d} = PHONE;
  const sw = w - 2 * BEZEL;
  const sh = (sw * PHONE.screenPt.h) / PHONE.screenPt.w;
  const lensZ = -d / 2 - 0.012; // задняя поверхность плато
  return {
    body: roundedSlab(w, h, BODY_R, d, EDGE),
    face: new THREE.ShapeGeometry(faceShape(w, h, BODY_R, EDGE), 24),
    screen: new THREE.PlaneGeometry(sw, sh),
    plateau: roundedSlab(0.3, 0.3, 0.07, 0.012, 0.004),
    ring: new THREE.CylinderGeometry(0.04, 0.042, 0.008, 40),
    lens: new THREE.CylinderGeometry(0.033, 0.033, 0.002, 40),
    flash: new THREE.CylinderGeometry(0.013, 0.013, 0.002, 32),
    lensZ,
    sw,
    sh,
  };
};

const SIDE_BUTTONS: {side: -1 | 1; y: number; hh: number}[] = [
  {side: -1, y: 0.42, hh: 0.04}, // action
  {side: -1, y: 0.3, hh: 0.07}, // volume +
  {side: -1, y: 0.18, hh: 0.07}, // volume −
  {side: 1, y: 0.38, hh: 0.12}, // side button
  {side: 1, y: -0.2, hh: 0.06}, // camera control
];

// Плато с тремя объективами и вспышкой — на задней стороне (−Z).
const PLATEAU_C: [number, number] = [0.13, 0.5];
const LENSES: [number, number][] = [
  [-0.065, 0.065],
  [0.065, 0.065],
  [-0.065, -0.065],
];
const FLASH: [number, number] = [0.065, -0.065];

const Phone3DBody: React.FC<{screenMat: THREE.ShaderMaterial}> = ({screenMat}) => {
  const {width: w, depth: d} = PHONE;
  const geo = useMemo(buildPhoneGeo, []);
  const mats = useMemo(makeMaterials, []);
  const rot90X: [number, number, number] = [Math.PI / 2, 0, 0];
  const z = d / 2;
  return (
    <group>
      {/* корпус */}
      <mesh geometry={geo.body} material={mats.titanium} />
      <mesh geometry={geo.face} material={mats.black} position={[0, 0, z + 0.0004]} />
      <mesh geometry={geo.screen} material={screenMat} position={[0, 0, z + 0.0008]} />
      <mesh geometry={geo.face} material={mats.glass} position={[0, 0, z + 0.0012]} renderOrder={2} />
      {/* задняя стеклянная панель */}
      <mesh geometry={geo.face} material={mats.backGlass} position={[0, 0, -z - 0.0004]} rotation={[0, Math.PI, 0]} />
      {/* кнопки по бокам */}
      {SIDE_BUTTONS.map((b, i) => (
        <RoundedBox
          key={i}
          args={[0.012, b.hh, 0.02]}
          radius={0.004}
          smoothness={3}
          position={[(b.side * w) / 2, b.y, 0]}
          material={mats.titanium}
        />
      ))}
      {/* камера */}
      <mesh geometry={geo.plateau} material={mats.titanium} position={[PLATEAU_C[0], PLATEAU_C[1], -z - 0.006]} rotation={[0, Math.PI, 0]} />
      {LENSES.map(([x, y], i) => (
        <group key={i} position={[PLATEAU_C[0] + x, PLATEAU_C[1] + y, geo.lensZ]}>
          <mesh geometry={geo.ring} material={mats.titanium} rotation={rot90X} position={[0, 0, -0.004]} />
          <mesh geometry={geo.lens} material={mats.lensGlass} rotation={rot90X} position={[0, 0, -0.0085]} />
        </group>
      ))}
      <mesh
        geometry={geo.flash}
        material={mats.flash}
        rotation={rot90X}
        position={[PLATEAU_C[0] + FLASH[0], PLATEAU_C[1] + FLASH[1], geo.lensZ - 0.001]}
      />
    </group>
  );
};

export type PhoneProps = {
  time: number;
  textures: Record<ScreenName, THREE.Texture>;
  screens?: ScreenCue[];
  taps?: TapCue[];
} & JSX.IntrinsicElements['group'];

export const Phone3D: React.FC<PhoneProps> = ({time, textures, screens = GLOBAL_SCREENS, taps = GLOBAL_TAPS, ...rest}) => {
  const screenMat = useMemo(() => makeScreenMaterial([PHONE.screenPt.w, PHONE.screenPt.h], PHONE.screenPt.r, true), []);
  const cues = useMemo(() => [...screens].map((c) => ({...c, kind: c.kind ?? 'cut'}) as Cue).sort((a, b) => a.at - b.at), [screens]);
  const u = screenUniforms(screenMat);
  applyCues(u, cues, textures, time);
  applyTaps(u, taps, time);
  return (
    <group {...rest}>
      <Phone3DBody screenMat={screenMat} />
    </group>
  );
};

// ---------- Apple Watch ----------
const WATCH = {w: 0.42, h: 0.52, d: 0.1, r: 0.13, bevel: 0.03, screenW: 0.39, screenPt: {w: 205, h: 251, r: 48}};

const buildWatchGeo = () => {
  const {w, h, d, r, bevel, screenW, screenPt} = WATCH;
  const screenH = (screenW * screenPt.h) / screenPt.w;
  const band = (sign: 1 | -1) => {
    const ctrl = [
      [0, 0.255, -0.01],
      [0, 0.33, -0.06],
      [0, 0.42, -0.18],
      [0, 0.46, -0.34],
      [0, 0.42, -0.52],
      [0, 0.3, -0.66],
      [0, 0.1, -0.74],
    ].map(([x, y, zz]) => new THREE.Vector3(x, y * sign, zz));
    return ribbonGeometry(new THREE.CatmullRomCurve3(ctrl), 0.36, 0.03, 80);
  };
  return {
    body: roundedSlab(w, h, r, d, bevel),
    face: new THREE.ShapeGeometry(faceShape(w, h, r, bevel), 24),
    screen: new THREE.PlaneGeometry(screenW, screenH),
    crown: new THREE.CylinderGeometry(0.03, 0.03, 0.05, 40),
    bandTop: band(1),
    bandBottom: band(-1),
  };
};

export type WatchProps = {time: number; texture: THREE.Texture; tapAt?: number} & JSX.IntrinsicElements['group'];

export const Watch3D: React.FC<WatchProps> = ({time, texture, tapAt, ...rest}) => {
  const screenMat = useMemo(() => makeScreenMaterial([WATCH.screenPt.w, WATCH.screenPt.h], WATCH.screenPt.r, false), []);
  const geo = useMemo(buildWatchGeo, []);
  const mats = useMemo(
    () => ({
      case: new THREE.MeshPhysicalMaterial({color: '#505256', metalness: 1, roughness: 0.32, envMapIntensity: 1.1}),
      crown: new THREE.MeshPhysicalMaterial({color: '#2a2b2e', metalness: 1, roughness: 0.4}),
      black: new THREE.MeshPhysicalMaterial({color: '#050505', roughness: 0.25, clearcoat: 0.5, clearcoatRoughness: 0.2}),
      glass: makeMaterials().glass,
      band: new THREE.MeshPhysicalMaterial({
        color: '#2e5e3a',
        roughness: 0.6,
        sheen: 0.4,
        sheenRoughness: 0.5,
        sheenColor: new THREE.Color('#3f6e4a'),
        side: THREE.DoubleSide,
      }),
    }),
    [],
  );
  const u = screenUniforms(screenMat);
  u.tA.value = texture;
  u.tB.value = texture;
  u.uKind.value = 0;
  u.uP.value = 1;
  applyTaps(u, tapAt == null ? [] : [{at: tapAt, x: WATCH.screenPt.w / 2, y: WATCH.screenPt.h / 2, water: false}], time);
  const z = WATCH.d / 2;
  const sideX = WATCH.w / 2;
  return (
    <group {...rest}>
      <mesh geometry={geo.body} material={mats.case} />
      <mesh geometry={geo.face} material={mats.black} position={[0, 0, z + 0.0004]} />
      <mesh geometry={geo.screen} material={screenMat} position={[0, 0, z + 0.0008]} />
      <mesh geometry={geo.face} material={mats.glass} position={[0, 0, z + 0.0012]} renderOrder={2} />
      {/* заводная головка и боковая кнопка */}
      <mesh geometry={geo.crown} material={mats.crown} rotation={[0, 0, Math.PI / 2]} position={[sideX + 0.012, 0.12, 0]} />
      <RoundedBox args={[0.02, 0.07, 0.03]} radius={0.006} smoothness={3} position={[sideX + 0.008, -0.06, 0]} material={mats.case} />
      {/* ремешок: верх и низ */}
      <mesh geometry={geo.bandTop} material={mats.band} />
      <mesh geometry={geo.bandBottom} material={mats.band} />
    </group>
  );
};

// ---------- Превью ----------
// В рендере Remotion канвас рисует только через advance() на смене кадра (frameloop: never).
// Текстуры грузятся позже, поэтому держим снимок и дорисовываем кадры, пока картинки не загружены.
const Draw: React.FC<{textures: THREE.Texture[]; hold: number}> = ({textures, hold}) => {
  const advance = useThree((st) => st.advance);
  useEffect(() => {
    let loadedTicks = 0;
    let ticks = 0;
    let released = false;
    const id = setInterval(() => {
      advance(performance.now());
      ticks++;
      loadedTicks = textures.every((t) => t.image) ? loadedTicks + 1 : 0;
      if (!released && (loadedTicks >= 3 || ticks > 400)) {
        released = true;
        continueRender(hold);
        clearInterval(id);
      }
    }, 30);
    return () => clearInterval(id);
  }, [advance, textures, hold]);
  return null;
};

export const Phone3DPreview: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const time = frame / fps;
  const textures = useScreenTextures();
  const watchTexture = useMemo(() => textures.watch, [textures]);
  const [hold] = useState(() => delayRender('phone preview: gpu upload'));
  return (
    <AbsoluteFill style={{background: '#050505'}}>
      <ThreeCanvas width={W} height={H} camera={{fov: 30, position: [0, 0, 6], near: 0.1, far: 60}} gl={{antialias: true}}>
        <color attach="background" args={['#050505']} />
        <Environment resolution={256} frames={1} background={false}>
          <Lightformer form="rect" intensity={4} position={[-3, 3, 4]} scale={[4, 3, 1]} target={[0, 0, 0]} color="#ffffff" />
          <Lightformer form="rect" intensity={3} position={[4, 0, 2]} scale={[1, 5, 1]} target={[0, 0, 0]} color="#f2f6ff" />
          <Lightformer form="rect" intensity={1.5} position={[0, 5, 0]} scale={[5, 5, 1]} target={[0, 0, 0]} color="#ffffff" />
          <Lightformer form="rect" intensity={3} position={[-4, 0, -3]} scale={[1, 6, 1]} target={[0, 0, 0]} color="#ffffff" />
          <Lightformer form="rect" intensity={2.5} position={[4, 1, -3]} scale={[1, 4, 1]} target={[0, 0, 0]} color="#dfe8ff" />
          <Lightformer form="rect" intensity={0.4} position={[0, -4, 4]} scale={[6, 1, 1]} target={[0, 0, 0]} color="#ffffff" />
        </Environment>
        <directionalLight position={[-3, 2, -3]} intensity={1.5} />
        <directionalLight position={[3, -2, 3]} intensity={0.3} />
        <Phone3D time={time} textures={textures} rotation={[0, Math.sin(time * 0.5) * 0.6, 0]} />
        <Watch3D time={time} texture={watchTexture} position={[0.5, -0.5, 0.25]} rotation={[0, -0.35, 0]} />
        <Draw textures={Object.values(textures)} hold={hold} />
      </ThreeCanvas>
    </AbsoluteFill>
  );
};
