// Студия ролика C: свет, зеркальный пол, узор приложения с волной полива, пыль, постэффекты.
import React, {useLayoutEffect, useMemo} from 'react';
import {useCurrentFrame, useVideoConfig} from 'remotion';
import {ThreeCanvas} from '@remotion/three';
import {useThree} from '@react-three/fiber';
import {Environment, Lightformer, MeshReflectorMaterial, RoundedBox} from '@react-three/drei';
import {Bloom, ChromaticAberration, EffectComposer, Noise, ToneMapping, Vignette} from '@react-three/postprocessing';
import {
  AdditiveBlending,
  CanvasTexture,
  Color,
  InstancedBufferAttribute,
  InstancedMesh,
  Matrix4,
  MeshBasicMaterial,
  Quaternion,
  Shape,
  ShapeGeometry,
  ShaderMaterial,
  SRGBColorSpace,
  Vector2,
  Vector3,
} from 'three';
import {BlendFunction, ToneMappingMode} from 'postprocessing';
import {COL, DROP, DROP_C, FLOOR_Y, LEAF, LEAF_C, M, W, H, clamp01, easeInOut} from './shared';

export type Wave = {t0: number; x: number; z: number; strength?: number}; // секунды, координаты пола
export type Collapse = {t0: number; x: number; z: number; seconds: number};

// Цвет горизонта: им же затухает пол, чтобы не было линии.
const HORIZON = '#0b0d0e';

// Узор: фигурка ≈ 0.12 в ширину (путь в pt, масштаб общий для листа и капли).
const FIG = (0.16 / 50.2067) * 0.75;
const PITCH_X = 0.32;
const PITCH_Z = 0.28;
const REACH = 7; // единицы пола, на которые волна доходит за cheerSeconds·(1−popSpan)
const MAX_R = REACH * 1.25; // полуразмер плоскости свечения
const GRID_X = [-6.2, 6.2] as const;
const GRID_Z = [-9.2, 3.2] as const;

const REST = new Color(COL.vividGreen).multiplyScalar(0.07);
const HOT = new Color(COL.waveBlue).multiplyScalar(4);
const BAND = new Color(COL.waveBlue).multiplyScalar(2.2);

const gauss = (v: number, s: number) => Math.exp(-(v / s) * (v / s));

// Детерминированный генератор, чтобы пыль не менялась между кадрами.
const mulberry32 = (seed: number) => () => {
  seed |= 0;
  seed = (seed + 0x6d2b79f5) | 0;
  let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
  t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
};

// Путь из SVG → плоская геометрия в плоскости XZ, центр в начале координат.
const glyph = (d: string, c: number[]) => {
  // Пути приложения состоят только из M/C/Z в абсолютных координатах.
  const tok = d.match(/[MCZ]|-?[\d.]+/g) ?? [];
  const shape = new Shape();
  let i = 0;
  let cmd = '';
  while (i < tok.length) {
    if (/[MCZ]/.test(tok[i])) cmd = tok[i++];
    if (cmd === 'Z') {
      shape.closePath();
      cmd = '';
    } else if (cmd === 'M') {
      shape.moveTo(+tok[i], +tok[i + 1]);
      i += 2;
      cmd = 'L';
    } else if (cmd === 'C') {
      shape.bezierCurveTo(+tok[i], +tok[i + 1], +tok[i + 2], +tok[i + 3], +tok[i + 4], +tok[i + 5]);
      i += 6;
    } else i++;
  }
  const g = new ShapeGeometry(shape);
  g.translate(-c[0], -c[1], 0);
  g.scale(FIG, FIG, 1); // без отрицательного масштаба: он переворачивает обмотку и грани уходят в culling
  g.rotateX(-Math.PI / 2);
  return g;
};

type Cell = {x: number; z: number};

// Сетка с полушагом в нечётных рядах; лист и капля чередуются в шахматном порядке.
const buildGrid = () => {
  const leaves: Cell[] = [];
  const drops: Cell[] = [];
  const nz = Math.ceil((GRID_Z[1] - GRID_Z[0]) / PITCH_Z);
  const nx = Math.ceil((GRID_X[1] - GRID_X[0]) / PITCH_X);
  for (let iz = 0; iz <= nz; iz++) {
    for (let ix = 0; ix <= nx; ix++) {
      const x = GRID_X[0] + ix * PITCH_X + (iz % 2 ? PITCH_X / 2 : 0);
      const z = GRID_Z[0] + iz * PITCH_Z;
      if (x > GRID_X[1] + PITCH_X / 2 || z > GRID_Z[1]) continue;
      ((ix + iz) % 2 === 0 ? leaves : drops).push({x, z});
    }
  }
  return {leaves, drops};
};

const GRID_MAX_D = (() => {
  const corners = [
    [GRID_X[0], GRID_Z[0]],
    [GRID_X[0], GRID_Z[1]],
    [GRID_X[1], GRID_Z[0]],
    [GRID_X[1], GRID_Z[1]],
  ];
  return (cx: number, cz: number) => Math.max(...corners.map(([x, z]) => Math.hypot(x - cx, z - cz)));
})();

// Видимость покоя: узор проявляется ближе к центру пола и дальше от камеры.
const restVis = (x: number, z: number) => {
  const centre = gauss(Math.hypot(x, z + 2), 6);
  const nearCam = clamp01((2.2 - z) / 3);
  return centre * nearCam;
};

// Формула из Front.point / popSpan приложения, по всем волнам разом (max).
const fieldAt = (x: number, z: number, t: number, waves: Wave[], collapse?: Collapse) => {
  let crest = 0;
  let valley = 0;
  for (const w of waves) {
    const turn = Math.min(Math.hypot(x - w.x, z - w.z) / REACH, 1);
    const p = ((t - w.t0) / M.cheerSeconds - turn * (1 - M.popSpan)) / M.popSpan;
    const c = p > 0 && p < 1 ? gauss(p - 0.5, 0.13) : 0;
    crest = Math.max(crest, c * (w.strength ?? 1));
    valley = Math.max(valley, gauss(p - 0.2, 0.08) + gauss(p - 0.8, 0.08));
  }
  let scale = 1 + M.popAmp * crest - 0.2 * valley;
  let px = x;
  let pz = z;
  let heat = 0;
  if (collapse) {
    // Дальние фигурки уходят первыми, ближние — последними.
    const turnC = 1 - Math.min(Math.hypot(x - collapse.x, z - collapse.z) / GRID_MAX_D(collapse.x, collapse.z), 1);
    const pc = ((t - collapse.t0) / collapse.seconds - turnC * (1 - M.popSpan)) / M.popSpan;
    const e = easeInOut(pc);
    scale *= 1 - e;
    // Фигурки стягиваются к точке схлопывания.
    px = x + (collapse.x - x) * 0.6 * e;
    pz = z + (collapse.z - z) * 0.6 * e;
    // Ближние к центру разгораются перед исчезновением.
    heat = turnC * Math.exp(-Math.pow((pc - 0.6) / 0.22, 2));
  }
  return {scale, crest: clamp01(crest), heat: clamp01(heat), px, pz};
};

const makeSpriteTexture = () => {
  const cv = document.createElement('canvas');
  cv.width = cv.height = 64;
  const ctx = cv.getContext('2d');
  if (ctx) {
    const g = ctx.createRadialGradient(32, 32, 0, 32, 32, 32);
    g.addColorStop(0, 'rgba(255,255,255,1)');
    g.addColorStop(0.35, 'rgba(255,255,255,0.35)');
    g.addColorStop(1, 'rgba(255,255,255,0)');
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, 64, 64);
  }
  return new CanvasTexture(cv);
};

// Фон: почти чёрный сверху, с подъёмом графита к горизонту (≈ 0.34 высоты кадра).
const makeBackgroundTexture = () => {
  const cv = document.createElement('canvas');
  cv.width = 4;
  cv.height = 512;
  const ctx = cv.getContext('2d');
  if (ctx) {
    const g = ctx.createLinearGradient(0, 0, 0, 512);
    g.addColorStop(0, '#010202');
    g.addColorStop(0.3, '#06080a');
    g.addColorStop(0.34, HORIZON);
    g.addColorStop(1, HORIZON);
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, 4, 512);
  }
  const t = new CanvasTexture(cv);
  t.colorSpace = SRGBColorSpace;
  return t;
};

// Радиальная маска: пол растворяется в цвете горизонта, край плоскости не виден.
const makeFadeTexture = () => {
  const cv = document.createElement('canvas');
  cv.width = cv.height = 256;
  const ctx = cv.getContext('2d');
  if (ctx) {
    const g = ctx.createRadialGradient(128, 128, 0, 128, 128, 128);
    g.addColorStop(0, 'rgba(11,13,14,0)');
    g.addColorStop(0.06, 'rgba(11,13,14,0)');
    g.addColorStop(0.33, 'rgba(11,13,14,1)');
    g.addColorStop(1, 'rgba(11,13,14,1)');
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, 256, 256);
  }
  const t = new CanvasTexture(cv);
  t.colorSpace = SRGBColorSpace;
  return t;
};

const BAND_VS = `
varying vec2 vUv;
void main() {
  vUv = uv;
  gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
}`;

// Гауссово свечение вдоль фронта волны: узкое ядро и мягкий ореол.
const BAND_FS = `
uniform vec3 uColor;
uniform float uR;
uniform float uW;
uniform float uAmp;
uniform float uMax;
varying vec2 vUv;
void main() {
  vec2 p = (vUv - 0.5) * 2.0 * uMax;
  float d = length(p);
  float g = exp(-pow((d - uR) / uW, 2.0)) + 0.25 * exp(-pow((d - uR) / (3.0 * uW), 2.0));
  gl_FragColor = vec4(uColor * g * uAmp, 1.0);
}`;

const Band: React.FC<{time: number; wave: Wave}> = ({time, wave}) => {
  const mat = useMemo(
    () =>
      new ShaderMaterial({
        uniforms: {
          uColor: {value: BAND},
          uR: {value: 0},
          uW: {value: 0.35},
          uAmp: {value: 0},
          uMax: {value: MAX_R},
        },
        vertexShader: BAND_VS,
        fragmentShader: BAND_FS,
        transparent: true,
        depthWrite: false,
        blending: AdditiveBlending,
      }),
    [],
  );
  // Фронт совпадает с гребнем: гребень у τ = (t/cheer − popSpan/2)/(1 − popSpan).
  const front = ((time - wave.t0) / M.cheerSeconds - M.popSpan / 2) / (1 - M.popSpan);
  const amp = clamp01(front * 6) * Math.pow(1 - clamp01(front), 1.5) * (wave.strength ?? 1);
  mat.uniforms.uR.value = Math.max(front, 0) * REACH;
  mat.uniforms.uAmp.value = amp * 1.2;
  return (
    <mesh rotation={[-Math.PI / 2, 0, 0]} position={[wave.x, FLOOR_Y + 0.008, wave.z]} material={mat}>
      <planeGeometry args={[2 * MAX_R, 2 * MAX_R]} />
    </mesh>
  );
};

const Field: React.FC<{time: number; waves: Wave[]; collapse?: Collapse}> = ({time, waves, collapse}) => {
  const grid = useMemo(buildGrid, []);
  const geoLeaf = useMemo(() => glyph(LEAF, LEAF_C), []);
  const geoDrop = useMemo(() => glyph(DROP, DROP_C), []);

  const matFig = useMemo(() => new MeshBasicMaterial({color: '#ffffff', toneMapped: false, fog: false}), []);
  const leafMesh = useMemo(() => {
    const m = new InstancedMesh(geoLeaf, matFig, grid.leaves.length);
    m.instanceColor = new InstancedBufferAttribute(new Float32Array(grid.leaves.length * 3), 3);
    return m;
  }, [geoLeaf, grid, matFig]);
  const dropMesh = useMemo(() => {
    const m = new InstancedMesh(geoDrop, matFig, grid.drops.length);
    m.instanceColor = new InstancedBufferAttribute(new Float32Array(grid.drops.length * 3), 3);
    return m;
  }, [geoDrop, grid, matFig]);

  useLayoutEffect(() => {
    const pos = new Vector3();
    const scl = new Vector3();
    const mat = new Matrix4();
    const quat = new Quaternion();
    const col = new Color();
    const fill = (mesh: InstancedMesh, cells: Cell[]) => {
      cells.forEach((c, i) => {
        const f = fieldAt(c.x, c.z, time, waves, collapse);
        const s = Math.max(f.scale, 0);
        pos.set(f.px, FLOOR_Y + 0.012 + 0.04 * f.crest, f.pz);
        scl.set(s, s, s);
        mat.compose(pos, quat, scl);
        mesh.setMatrixAt(i, mat);
        col.copy(REST).multiplyScalar(restVis(c.x, c.z)).lerp(HOT, clamp01(f.crest + 0.9 * f.heat));
        mesh.setColorAt(i, col);
      });
      mesh.instanceMatrix.needsUpdate = true;
      if (mesh.instanceColor) mesh.instanceColor.needsUpdate = true;
    };
    fill(leafMesh, grid.leaves);
    fill(dropMesh, grid.drops);
  }, [time, waves, collapse, leafMesh, dropMesh, grid]);

  return (
    <>
      <primitive object={leafMesh} />
      <primitive object={dropMesh} />
      {waves.map((w, i) => (
        <Band key={i} time={time} wave={w} />
      ))}
    </>
  );
};

const Motes: React.FC<{time: number}> = ({time}) => {
  const count = 150;
  const seeds = useMemo(() => {
    const rnd = mulberry32(42);
    const base = new Float32Array(count * 3);
    const phase = new Float32Array(count * 3);
    for (let i = 0; i < count; i++) {
      base[i * 3] = (rnd() - 0.5) * 9;
      base[i * 3 + 1] = FLOOR_Y + 0.15 + rnd() * 4.2;
      base[i * 3 + 2] = -6 + rnd() * 8;
      for (let k = 0; k < 3; k++) phase[i * 3 + k] = rnd() * Math.PI * 2;
    }
    return {base, phase};
  }, []);
  const sprite = useMemo(makeSpriteTexture, []);
  const positions = useMemo(() => {
    const out = new Float32Array(count * 3);
    const {base, phase} = seeds;
    for (let i = 0; i < count; i++) {
      out[i * 3] = base[i * 3] + 0.1 * Math.sin(time * 0.31 + phase[i * 3]);
      out[i * 3 + 1] = base[i * 3 + 1] + 0.18 * Math.sin(time * 0.23 + phase[i * 3 + 1]);
      out[i * 3 + 2] = base[i * 3 + 2] + 0.1 * Math.sin(time * 0.19 + phase[i * 3 + 2]);
    }
    return out;
  }, [time, seeds]);

  return (
    <points>
      <bufferGeometry>
        <bufferAttribute attach="attributes-position" args={[positions, 3]} />
      </bufferGeometry>
      <pointsMaterial
        map={sprite}
        color="#cfeaff"
        size={0.025}
        sizeAttenuation
        transparent
        opacity={0.5}
        depthWrite={false}
        blending={AdditiveBlending}
        toneMapped={false}
      />
    </points>
  );
};

export const Studio: React.FC<{time: number; waves: Wave[]; collapse?: Collapse; warm?: number}> = ({
  time,
  waves,
  collapse,
  warm = 0,
}) => {
  const fade = useMemo(makeFadeTexture, []);
  const bg = useMemo(makeBackgroundTexture, []);
  return (
    <>
      <primitive attach="background" object={bg} />
      <fog attach="fog" args={[HORIZON, 9, 20]} />

      <Environment resolution={256} frames={1}>
        <Lightformer form="rect" intensity={0.8} position={[0, 6, 0]} rotation={[-Math.PI / 2, 0, 0]} scale={[8, 6, 1]} color="#ffffff" />
        <Lightformer form="rect" intensity={1.8} position={[-6, 1, -2]} rotation={[0, Math.PI / 2, 0]} scale={[1.2, 10, 1]} color={COL.water} />
        <Lightformer form="rect" intensity={1.6} position={[6, 1, -2]} rotation={[0, -Math.PI / 2, 0]} scale={[1.2, 10, 1]} color="#ffd6a8" />
        <Lightformer form="rect" intensity={0.6} position={[0, 2, -7]} scale={[12, 4, 1]} color="#ffffff" />
      </Environment>

      <ambientLight intensity={0.04} />
      <spotLight position={[2.6, 6.5, 4.5]} angle={0.5} penumbra={1} intensity={90} color="#f4f7ff" />
      <directionalLight position={[-4, 3.5, -6]} intensity={2.5} color="#bfe8ff" />
      <directionalLight position={[4, 2.5, -6]} intensity={1.6} color="#8fd6ff" />
      <pointLight position={[-0.6, FLOOR_Y + 1.5, -1]} intensity={3 + 9 * warm} color="#ffd9a6" decay={2} />

      <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, FLOOR_Y, 0]}>
        <planeGeometry args={[60, 60]} />
        <MeshReflectorMaterial
          resolution={256}
          blur={[200, 60]}
          mixBlur={1}
          mirror={0.75}
          color="#020303"
          metalness={0.6}
          roughness={0.9}
          envMapIntensity={0.15}
        />
      </mesh>
      <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, FLOOR_Y + 0.002, 0]}>
        <planeGeometry args={[60, 60]} />
        <meshBasicMaterial map={fade} transparent depthWrite={false} toneMapped={false} />
      </mesh>

      <Field time={time} waves={waves} collapse={collapse} />
      <Motes time={time} />
    </>
  );
};

export const Effects: React.FC<{time: number; bloom?: number; grain?: number}> = ({bloom = 1, grain = 1}) => {
  return (
    <EffectComposer multisampling={0}>
      <Bloom mipmapBlur luminanceThreshold={1.05} luminanceSmoothing={0.15} intensity={1.1 * bloom} radius={0.75} />
      <Noise premultiply blendFunction={BlendFunction.SCREEN} opacity={0.035 * grain} />
      <ChromaticAberration offset={new Vector2(0.0006, 0.0006)} radialModulation={false} modulationOffset={0} />
      <Vignette darkness={0.6} offset={0.3} />
      <ToneMapping mode={ToneMappingMode.ACES_FILMIC} />
    </EffectComposer>
  );
};

// ThreeCanvas не принимает lookAt: наводим камеру на центр кадра.
const Look: React.FC = () => {
  const camera = useThree((s) => s.camera);
  useLayoutEffect(() => {
    camera.lookAt(0, -0.2, 0);
  });
  return null;
};

export const StudioPreview: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const time = frame / fps;
  const waves: Wave[] = [
    {t0: 1.0, x: 0, z: 0.3},
    {t0: 4.0, x: 1, z: -1, strength: 0.6},
  ];
  const collapse: Collapse = {t0: 6.0, x: 0, z: 0, seconds: 1.4};
  return (
    <ThreeCanvas width={W} height={H} camera={{fov: 30, position: [0, 0.4, 7]}} gl={{antialias: false}}>
      <Look />
      <Studio time={time} waves={waves} collapse={collapse} />
      <RoundedBox args={[0.77, 1.6, 0.09]} radius={0.1} smoothness={4}>
        <meshStandardMaterial color="#9da3aa" metalness={1} roughness={0.28} />
      </RoundedBox>
      <mesh position={[-0.6, FLOOR_Y + 0.35, -1.6]}>
        <cylinderGeometry args={[0.35, 0.28, 0.7, 48]} />
        <meshStandardMaterial color="#2a2d2b" roughness={0.6} metalness={0.2} />
      </mesh>
      <Effects time={time} />
    </ThreeCanvas>
  );
};
