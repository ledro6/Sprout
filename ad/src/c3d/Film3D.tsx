// Режиссура ролика C в 3D: камера, телефон, часы, растение, волны и слой текста.
import React from 'react';
import {ThreeCanvas} from '@remotion/three';
import {useThree} from '@react-three/fiber';
import {AbsoluteFill, continueRender, delayRender, useCurrentFrame, useVideoConfig} from 'remotion';
import type {Texture} from 'three';
import {Phone3D, Watch3D} from './Phone3D';
import {Plant3D} from './Plant3D';
import {Effects, Studio} from './Studio';
import {Overlay} from './Overlay';
import {COL, FLOOR_Y, SCENES, clamp01, easeInOut, sceneAt, sceneStarts, sui, useScreenTextures} from './shared';

type V3 = [number, number, number];
type Shot = {
  cam: V3; // где камера
  look: V3; // куда смотрит
  phone: V3; // где телефон
  rot: V3; // поворот телефона, рад
  scale?: number;
  fov?: number;
};

const start = (id: string) => sceneStarts[SCENES.findIndex((s) => s.id === id)];
const TAP_WATER = start('remember') + 1.35;
const PLANT: V3 = [-0.78, FLOOR_Y, -1.75];
const HIDDEN: V3 = [1.8, -3.2, 1.2];

// Кадр каждой сцены: в начале и в конце (между ними — медленный наезд камеры).
const SHOTS: Record<string, {from: Shot; to: Shot}> = {
  hook: {
    from: {cam: [-0.2, 0.9, 4.8], look: [-0.75, -0.1, -1.75], phone: HIDDEN, rot: [0, -1.2, 0.3]},
    to: {cam: [-0.45, 0.6, 3.9], look: [-0.75, -0.05, -1.75], phone: HIDDEN, rot: [0, -1.2, 0.3]},
  },
  remember: {
    from: {cam: [0.5, 0.55, 5.4], look: [0, 0.42, 0], phone: [0, 0, 0.35], rot: [0.04, -0.32, 0.02]},
    to: {cam: [-0.35, 0.75, 6.3], look: [-0.25, 0.3, -0.4], phone: [0.15, 0, 0.35], rot: [0.02, 0.18, 0]},
  },
  greets: {
    from: {cam: [1.1, 0.5, 5.4], look: [0, 0.45, 0], phone: [0, 0, 0.3], rot: [0.03, 0.34, -0.02]},
    to: {cam: [0.8, 0.45, 5.0], look: [0, 0.45, 0], phone: [0, 0, 0.3], rot: [0.03, 0.22, -0.02]},
  },
  knows: {
    from: {cam: [-1.0, -0.15, 5.2], look: [0, 0.4, 0], phone: [0, 0, 0.3], rot: [-0.08, -0.36, 0.03]},
    to: {cam: [-0.6, -0.05, 4.8], look: [0, 0.42, 0], phone: [0, 0, 0.3], rot: [-0.05, -0.22, 0.02]},
  },
  names: {
    from: {cam: [0.2, 0.35, 4.6], look: [0, 0.4, 0], phone: [0, 0, 0.35], rot: [0.02, 0.12, 0]},
    to: {cam: [0.0, 0.32, 4.25], look: [0, 0.38, 0], phone: [0, 0, 0.35], rot: [0.02, 0.02, 0]},
  },
  heals: {
    from: {cam: [1.2, 0.9, 5.6], look: [0, 0.4, 0], phone: [0, 0, 0.3], rot: [0.06, 0.3, 0.07]},
    to: {cam: [0.9, 0.7, 5.1], look: [0, 0.42, 0], phone: [0, 0, 0.3], rot: [0.05, 0.16, 0.05]},
  },
  answers: {
    from: {cam: [-0.3, 0.45, 5.1], look: [0, 0.42, 0], phone: [0, 0, 0.35], rot: [0.02, -0.12, 0]},
    to: {cam: [0.1, 0.4, 4.55], look: [0, 0.4, 0], phone: [0, 0, 0.35], rot: [0.02, 0.05, 0]},
  },
  draws: {
    from: {cam: [-1.3, 0.35, 5.4], look: [0, 0.42, 0], phone: [0, 0, 0.3], rot: [0.03, -0.38, -0.03]},
    to: {cam: [-1.0, 0.4, 5.0], look: [0, 0.42, 0], phone: [0, 0, 0.3], rot: [0.03, -0.24, -0.02]},
  },
  orbits: {
    from: {cam: [0.2, 3.4, 4.2], look: [0, -0.35, 0], phone: [0, -0.35, 0.2], rot: [-1.05, 0, 0.25]},
    to: {cam: [-0.4, 3.0, 3.8], look: [0, -0.35, 0], phone: [0, -0.35, 0.2], rot: [-1.05, 0, 0.55]},
  },
  wrist: {
    from: {cam: [0.4, 0.45, 5.6], look: [0.15, 0.32, 0], phone: [-0.42, 0, 0.1], rot: [0.03, 0.3, 0], scale: 0.9},
    to: {cam: [0.2, 0.4, 5.2], look: [0.15, 0.32, 0], phone: [-0.42, 0, 0.1], rot: [0.03, 0.2, 0], scale: 0.9},
  },
  family: {
    from: {cam: [-0.9, 0.65, 5.6], look: [0, 0.42, 0], phone: [0, 0, 0.3], rot: [0.04, -0.3, 0.02]},
    to: {cam: [-0.6, 0.55, 5.1], look: [0, 0.42, 0], phone: [0, 0, 0.3], rot: [0.03, -0.12, 0.01]},
  },
  private: {
    from: {cam: [0.0, 0.5, 5.0], look: [0, 0.42, 0], phone: [0, 0, 0.35], rot: [0.05, 0.08, 0]},
    to: {cam: [0.0, 0.42, 4.5], look: [0, 0.4, 0], phone: [0, 0, 0.35], rot: [0.03, 0, 0]},
  },
  end: {
    from: {cam: [0, 0.9, 6.0], look: [0, 0.25, 0], phone: [0, 1.6, -2.5], rot: [0.4, 0.8, 0.2], scale: 0.4},
    to: {cam: [0, 1.4, 7.6], look: [0, 0.1, 0], phone: [0, 2.6, -4.0], rot: [0.4, 1.2, 0.2], scale: 0.2},
  },
};

const lerp = (a: number, b: number, p: number) => a + (b - a) * p;
const lerp3 = (a: V3, b: V3, p: number): V3 => [lerp(a[0], b[0], p), lerp(a[1], b[1], p), lerp(a[2], b[2], p)];
const shotLerp = (a: Shot, b: Shot, p: number, q = p): Shot => ({
  cam: lerp3(a.cam, b.cam, q),
  look: lerp3(a.look, b.look, q),
  phone: lerp3(a.phone, b.phone, p),
  rot: lerp3(a.rot, b.rot, p),
  scale: lerp(a.scale ?? 1, b.scale ?? 1, p),
  fov: lerp(a.fov ?? 30, b.fov ?? 30, q),
});

// Внутри сцены — медленный наезд; на стыке — быстрый перелёт: телефон пружиной,
// камера — плавной кривой за 0.55 с.
const shotAt = (t: number, fps: number): Shot => {
  const {index, scene, local} = sceneAt(t);
  const cur = SHOTS[scene.id];
  const inScene = shotLerp(cur.from, cur.to, easeInOut(local / scene.dur));
  if (index === 0) return inScene;
  const prev = SHOTS[SCENES[index - 1].id].to;
  const springP = sui(local * fps, fps, 0.6, 0.14);
  const camP = easeInOut(local / 0.55);
  return shotLerp(prev, inScene, springP, camP);
};

// Холст рисует только на смене кадра, а картинки экранов приходят позже:
// дорисовываем, пока все текстуры не загружены, и только тогда отпускаем снимок.
const Warm: React.FC<{textures: Texture[]}> = ({textures}) => {
  const advance = useThree((st) => st.advance);
  const [hold] = React.useState(() => delayRender('3d warmup'));
  React.useEffect(() => {
    let ok = 0;
    let ticks = 0;
    let done = false;
    const id = setInterval(() => {
      advance(performance.now());
      ticks++;
      ok = textures.every((t) => t.image) ? ok + 1 : 0;
      if (!done && (ok >= 3 || ticks > 4000)) {
        done = true;
        continueRender(hold);
        clearInterval(id);
      }
    }, 30);
    return () => clearInterval(id);
  }, [advance, textures, hold]);
  return null;
};

const CameraRig: React.FC<{shot: Shot}> = ({shot}) => {
  const {camera} = useThree();
  React.useLayoutEffect(() => {
    camera.position.set(...shot.cam);
    camera.lookAt(...shot.look);
    // @ts-expect-error fov есть у перспективной камеры
    camera.fov = shot.fov ?? 30;
    camera.updateProjectionMatrix();
  });
  return null;
};

// Планетарий в объёме: орбиты-кольца и планеты-растения над экраном.
const Orbits: React.FC<{t: number}> = ({t}) => {
  const up = sui(t * 30, 30, 0.8, 0.15);
  const rings = [
    {r: 0.32, h: 0.16, speed: 1.6, col: '#ff3b30'},
    {r: 0.52, h: 0.3, speed: 1.0, col: COL.vividGreen},
    {r: 0.74, h: 0.44, speed: 0.6, col: COL.water},
  ];
  return (
    <group position={[0, 0.25, 0]}>
      {rings.map((r, i) => {
        const a = t * r.speed + i * 2.1;
        return (
          <group key={i} position={[0, 0, r.h * up]}>
            <mesh>
              <torusGeometry args={[r.r, 0.004, 8, 128]} />
              <meshBasicMaterial color={r.col} toneMapped={false} transparent opacity={0.55 * up} />
            </mesh>
            <mesh position={[Math.cos(a) * r.r, Math.sin(a) * r.r, 0]} scale={up}>
              <sphereGeometry args={[0.045, 24, 24]} />
              <meshStandardMaterial color={r.col} emissive={r.col} emissiveIntensity={3} toneMapped={false} />
            </mesh>
          </group>
        );
      })}
    </group>
  );
};

export const Film3D: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps, width, height} = useVideoConfig();
  const t = frame / fps;
  const tex = useScreenTextures();
  const {scene, local} = sceneAt(t);
  const shot = shotAt(t, fps);

  // Растение: сухое → оживает после полива → цветёт.
  const health = sui((t - TAP_WATER - 0.25) * fps, fps, 1.0, 0.25);
  const bloom = clamp01(sui((t - TAP_WATER - 0.7) * fps, fps, 1.8, 0));

  // Волны по полу: смена сцены — тихая, полив — во всю силу, капля с хука — к растению.
  const waves = [
    {t0: 2.05, x: PLANT[0], z: PLANT[2], strength: 0.55},
    {t0: TAP_WATER + 0.1, x: 0, z: 0.4, strength: 1},
    ...SCENES.map((s, i) => ({s, i}))
      .filter(({s, i}) => i > 1 && !s.end)
      .map(({i}) => ({t0: sceneStarts[i], x: 0, z: 0.35, strength: 0.45})),
  ];
  const endStart = start('end');
  const collapse = {t0: endStart + 0.15, x: 0, z: 0, seconds: 1.5};

  const watchIn = scene.id === 'wrist' ? sui(local * fps - 5, fps, 0.6, 0.2) : 0;
  const watchOut = scene.id === 'wrist' ? clamp01((local - (scene.dur - 0.3)) / 0.3) : 0;
  const plantFade = scene.id === 'end' ? clamp01(local / 0.8) : 0;

  return (
    <AbsoluteFill style={{background: '#050607'}}>
      <ThreeCanvas width={width} height={height} camera={{fov: 30, near: 0.05, far: 60, position: [0, 0.5, 6]}}>
        <Warm textures={Object.values(tex)} />
        <CameraRig shot={shot} />
        <Studio time={t} waves={waves} collapse={collapse} warm={scene.id === 'hook' ? 1 : 0.4} />
        <group position={PLANT} scale={1 - 0.15 * plantFade} visible={plantFade < 1}>
          <Plant3D time={t} health={health} bloom={bloom} />
        </group>
        <group position={shot.phone} rotation={shot.rot} scale={shot.scale ?? 1}>
          <Phone3D time={t} textures={tex} />
          {scene.id === 'orbits' && <Orbits t={local} />}
        </group>
        {watchIn > 0.001 && (
          <group
            position={[0.62 + (1 - watchIn) * 1.2, -0.28 + (1 - watchIn) * -0.5 + watchOut * 0.4, 0.75]}
            rotation={[0.05, -0.38 + Math.sin(local * 1.2) * 0.06, -0.04]}
            scale={1.15 * (1 - watchOut * 0.3)}
          >
            <Watch3D time={t} texture={tex.watch} tapAt={start('wrist') + 1.3} />
          </group>
        )}
        <Effects time={t} />
      </ThreeCanvas>
      {/* Под заголовком — затемнение, чтобы буквы не спорили со сценой. */}
      <AbsoluteFill style={{background: 'linear-gradient(180deg, rgba(3,4,4,0.82) 0%, rgba(3,4,4,0.55) 24%, rgba(3,4,4,0) 40%)'}} />
      <Overlay time={t} />
    </AbsoluteFill>
  );
};
