// Растение для 3D-ролика: здоровье и цветение управляют геометрией и материалами.
import React, {Suspense, useMemo} from 'react';
import * as THREE from 'three';
import {useCurrentFrame, useVideoConfig} from 'remotion';
import {ThreeCanvas} from '@remotion/three';
import {Environment, Lightformer} from '@react-three/drei';
import {useThree} from '@react-three/fiber';
import {H, W} from './shared';
import {
  buildLeaf,
  buildMidrib,
  buildPetal,
  buildPot,
  buildSoil,
  buildTube,
  clamp01,
  easeOutBack,
  easeOutCubic,
  lerp,
  makeLeafMap,
  makeShadowMap,
  mulberry32,
  negateNormals,
  smooth,
} from './Plant3D.geo';

const UP = new THREE.Vector3(0, 1, 0);
const Z_AX = new THREE.Vector3(0, 0, 1);
const SOIL_Y = 0.6;
const PETAL_R = 0.088;
const PETAL_D = 0.1;
const PETAL_CUP = 0.035;
const LEAF_LEN = 0.72; // мировая длина клинка при size=1

// Раскладка — один раз, из seeded PRNG.
// Лист: здоровый — черенок вверх, клинок свисает под 34–57°; сухой — клинок ниже края горшка.
const rnd = mulberry32(7741);
const LEAVES = Array.from({length: 9}, (_, i) => ({
  phi: i * 2.39996 + (rnd() - 0.5) * 0.35,
  hH: 1.45 + 0.75 * rnd(),
  rH: 0.14 + 0.2 * rnd(),
  tiltH: -0.6 - 0.4 * rnd(),
  size: 0.9 + 0.25 * rnd(),
  hD: 0.8 + 0.08 * rnd(),
  rD: 0.3 + 0.1 * rnd(),
  tiltD: -1.1 - 0.2 * rnd(),
  bow: rnd(),
}));
const FLOWERS = Array.from({length: 6}, (_, i) => ({
  phi: i * 1.0472 + 0.5 + (rnd() - 0.5) * 0.5,
  rH: 0.2 + 0.2 * rnd(),
  hH: 2.05 + 0.3 * rnd(),
  rD: 0.5 + 0.1 * rnd(),
  hD: 0.95 + 0.25 * rnd(),
  delay: rnd() * 0.4,
  spin: rnd() * Math.PI * 2,
}));

type PlantProps = {time: number; health: number; bloom: number} & JSX.IntrinsicElements['group'];

const DRY_F = new THREE.Color('#7a7434');
const HEALTHY_F = new THREE.Color('#2aa34e');
const DRY_B = new THREE.Color('#8f8848');
const HEALTHY_B = new THREE.Color('#8fc24e');
const PET_DRY = new THREE.Color('#6d6e33');
const PET_OK = new THREE.Color('#2d7a3c');
const STEM_OK = new THREE.Color('#2a9a45');

export const Plant3D: React.FC<PlantProps> = ({time, health, bloom, ...rest}) => {
  // Квантуем здоровье: геометрия пересобирается лишь при заметном изменении.
  const hq = Math.round(clamp01(health) * 200) / 200;
  const e = smooth(hq);
  const b = clamp01(bloom);
  const t = time;

  const assets = useMemo(() => {
    const leafMap = makeLeafMap();
    const petalGeo = buildPetal(PETAL_R, PETAL_D, PETAL_CUP);
    return {
      leafFront: new THREE.MeshPhysicalMaterial({
        map: leafMap,
        color: HEALTHY_F,
        roughness: 0.4,
        clearcoat: 0.35,
        clearcoatRoughness: 0.25,
        sheen: 0.2,
        sheenColor: new THREE.Color('#b9ffcf'),
        sheenRoughness: 0.45,
        envMapIntensity: 1.4,
        side: THREE.FrontSide,
      }),
      leafBack: new THREE.MeshPhysicalMaterial({
        map: leafMap,
        color: HEALTHY_B,
        roughness: 0.5,
        clearcoat: 0.1,
        sheen: 0.6,
        sheenColor: new THREE.Color('#eaffb0'),
        sheenRoughness: 0.5,
        envMapIntensity: 1.2,
        side: THREE.BackSide,
      }),
      petMat: new THREE.MeshPhysicalMaterial({roughness: 0.7, side: THREE.DoubleSide}),
      stemMat: new THREE.MeshPhysicalMaterial({color: STEM_OK, roughness: 0.7}),
      petalMat: new THREE.MeshPhysicalMaterial({
        vertexColors: true,
        roughness: 0.38,
        clearcoat: 0.6,
        clearcoatRoughness: 0.25,
        sheen: 0.5,
        sheenColor: new THREE.Color('#ffb3c8'),
        sheenRoughness: 0.4,
        emissive: new THREE.Color('#ff5c80'),
        emissiveIntensity: 0.05,
        side: THREE.FrontSide,
      }),
      petalBackMat: new THREE.MeshStandardMaterial({color: '#d9466f', roughness: 0.5, side: THREE.BackSide}),
      centreMat: new THREE.MeshStandardMaterial({color: '#ffd65c', roughness: 0.5, emissive: new THREE.Color('#ffb020'), emissiveIntensity: 0.1}),
      stamenMat: new THREE.MeshStandardMaterial({color: '#ffcf40', roughness: 0.5}),
      calyxMat: new THREE.MeshPhysicalMaterial({color: '#2e8f43', roughness: 0.5, clearcoat: 0.2}),
      potMat: new THREE.MeshPhysicalMaterial({color: '#202225', roughness: 0.7, side: THREE.DoubleSide}),
      rimMat: new THREE.MeshPhysicalMaterial({color: '#2b2d31', roughness: 0.2, clearcoat: 1, clearcoatRoughness: 0.08, side: THREE.DoubleSide}),
      soilMat: new THREE.MeshStandardMaterial({color: '#2b1f15', roughness: 1}),
      potGeo: buildPot().body,
      rimGeo: buildPot().rim,
      soilGeo: buildSoil(),
      petalGeo,
      petalBackGeo: negateNormals(petalGeo),
      centreGeo: new THREE.SphereGeometry(0.032, 16, 10),
      stamenGeo: new THREE.SphereGeometry(0.0045, 8, 6),
      calyxGeo: new THREE.SphereGeometry(0.042, 16, 12),
    };
  }, []);

  // Геометрия, зависящая от здоровья: лист, жилка, черенки, стебли.
  const geo = useMemo(() => {
    const e2 = smooth(hq);
    const up = UP;
    const leafGeo = buildLeaf(hq);
    const midGeo = buildMidrib(hq);
    const leaves = LEAVES.map((L) => {
      const Ay = lerp(L.hD, L.hH, e2);
      const Ar = lerp(L.rD, L.rH, e2);
      const tilt = lerp(L.tiltD, L.tiltH, e2);
      const len = LEAF_LEN * L.size * lerp(0.6, 1, e2);
      const o = new THREE.Vector3(Math.cos(L.phi), 0, Math.sin(L.phi));
      const A = new THREE.Vector3(o.x * Ar, Ay, o.z * Ar);
      const B = new THREE.Vector3(o.x * 0.08, SOIL_Y, o.z * 0.08);
      // Направление клинка: tilt < 0 — кончик вниз и наружу.
      const d = o.clone().multiplyScalar(Math.cos(tilt)).addScaledVector(up, Math.sin(tilt)).normalize();
      // Базис листа: кончик — по −Y, нормаль +Z (вверх для наклонённого вниз клинка).
      const xAx = new THREE.Vector3().crossVectors(up, d).normalize();
      const yAx = d.clone().negate();
      const zAx = new THREE.Vector3().crossVectors(xAx, yAx);
      const q = new THREE.Quaternion().setFromRotationMatrix(new THREE.Matrix4().makeBasis(xAx, yAx, zAx));
      // Черенок выгибается вверх от почвы, затем клинок свисает.
      const lift = lerp(0.02, 0.32, e2) * (0.6 + L.bow);
      const mid = B.clone().lerp(A, 0.5).addScaledVector(up, lift);
      const pet = buildTube([B, mid, A], lerp(0.009, 0.007, e2));
      return {A, q, len, pet};
    });
    const flowers = FLOWERS.map((F) => {
      const o = new THREE.Vector3(Math.cos(F.phi), 0, Math.sin(F.phi));
      const Hr = lerp(F.rD, F.rH, e2);
      const H = new THREE.Vector3(o.x * Hr, lerp(F.hD, F.hH, e2), o.z * Hr);
      const Bp = new THREE.Vector3(o.x * 0.1, SOIL_Y, o.z * 0.1);
      // Сухие стебли провисают: изгиб наружу и вниз.
      const mid = Bp.clone().lerp(H, 0.5).addScaledVector(o, lerp(0.2, 0.02, e2));
      mid.y -= (1 - e2) * 0.15;
      const stem = buildTube([Bp, mid, H], lerp(0.009, 0.007, e2));
      // Сухие цветки смотрят вниз и вбок, здоровые — вверх и наружу.
      const tilt = lerp(1.9, 0.45, e2);
      const axis = o.clone().multiplyScalar(Math.sin(tilt)).addScaledVector(up, Math.cos(tilt)).normalize();
      const q = new THREE.Quaternion().setFromUnitVectors(Z_AX, axis);
      return {H, q, stem, spin: F.spin, delay: F.delay};
    });
    return {leafGeo, leafBackGeo: negateNormals(leafGeo), midGeo, leaves, flowers};
  }, [hq]);

  // Цвета — по здоровью; геометрия не пересобирается.
  assets.leafFront.color.lerpColors(DRY_F, HEALTHY_F, e);
  assets.leafBack.color.lerpColors(DRY_B, HEALTHY_B, e);
  assets.petMat.color.lerpColors(PET_DRY, PET_OK, e);
  assets.stemMat.color.lerpColors(PET_DRY, STEM_OK, e);
  assets.petalMat.emissiveIntensity = 0.05 + 0.25 * b;

  // Цветение: каждый цветок раскрывается со своей задержкой; сухой бутон — 0.4 от здорового.
  const flowerState = geo.flowers.map((F) => {
    const p = clamp01((b - F.delay) / 0.6);
    const ob = easeOutBack(p, 1.1);
    return {
      alpha: lerp(1.2, 0.12, ob),
      scale: lerp(0.4, 1, e) * (0.55 + 0.45 * easeOutCubic(p)),
    };
  });

  return (
    <group {...rest}>
      <group rotation={[0.01 * Math.cos(t * 0.6 + 1), 0, 0.018 * Math.sin(t * 0.8)]}>
        <mesh geometry={assets.potGeo} material={assets.potMat} />
        <mesh geometry={assets.rimGeo} material={assets.rimMat} />
        <mesh geometry={assets.soilGeo} material={assets.soilMat} />

        {geo.leaves.map((L, i) => (
          <group key={'l' + i}>
            <mesh geometry={L.pet} material={assets.petMat} />
            <group position={L.A}>
              <group rotation={[0.035 * Math.sin(t * 1.1 + i * 1.7), 0, 0.03 * Math.cos(t * 0.9 + i * 1.3)]}>
                <group quaternion={L.q}>
                  <group scale={L.len}>
                    <mesh geometry={geo.leafGeo} material={assets.leafFront} />
                    <mesh geometry={geo.leafBackGeo} material={assets.leafBack} />
                    <mesh geometry={geo.midGeo} material={assets.leafFront} />
                  </group>
                </group>
              </group>
            </group>
          </group>
        ))}

        {geo.flowers.map((F, i) => {
          const fs = flowerState[i];
          return (
            <group key={'f' + i}>
              <mesh geometry={F.stem} material={assets.stemMat} />
              <group position={F.H} quaternion={F.q}>
                <group rotation={[0, 0, 0.03 * Math.sin(t * 1.2 + i)]}>
                  <group scale={fs.scale}>
                    {[0, 1, 2, 3, 4].map((k) => (
                      <group key={k} rotation={[0, 0, F.spin + (k * Math.PI * 2) / 5]}>
                        <mesh geometry={assets.petalGeo} material={assets.petalMat} rotation={[fs.alpha, 0, 0]} />
                        <mesh geometry={assets.petalBackGeo} material={assets.petalBackMat} rotation={[fs.alpha, 0, 0]} />
                      </group>
                    ))}
                    <mesh geometry={assets.centreGeo} material={assets.centreMat} position={[0, 0, 0.012]} scale={[1, 1, 0.55]} />
                    {Array.from({length: 12}, (_, k) => {
                      const a = (k / 12) * Math.PI * 2;
                      return (
                        <mesh
                          key={'s' + k}
                          geometry={assets.stamenGeo}
                          material={assets.stamenMat}
                          position={[Math.cos(a) * 0.04, Math.sin(a) * 0.04, 0.026]}
                        />
                      );
                    })}
                    <mesh geometry={assets.calyxGeo} material={assets.calyxMat} position={[0, 0, -0.02]} scale={[1, 1, 0.8]} />
                  </group>
                </group>
              </group>
            </group>
          );
        })}
      </group>
    </group>
  );
};

// Камера смотрит на центр растения; задаётся в каждом кадре, без состояния.
const LookAt: React.FC<{target: [number, number, number]}> = ({target}) => {
  const camera = useThree((s) => s.camera);
  camera.lookAt(target[0], target[1], target[2]);
  return null;
};

export const Plant3DPreview: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const time = frame / fps;
  const health = clamp01((time - 1) / 1.5);
  const bloom = clamp01((time - 3) / 2);
  const keyTarget = useMemo(() => new THREE.Object3D(), []);
  const shadow = useMemo(() => makeShadowMap(), []);

  return (
    <ThreeCanvas
      width={W}
      height={H}
      gl={{antialias: true}}
      camera={{fov: 30, position: [3.6, 2.7, 5.2], near: 0.1, far: 60}}
    >
      <color attach="background" args={['#050505']} />
      <fog attach="fog" args={['#050505', 5, 13]} />
      <LookAt target={[0, 1.15, 0]} />
      <Suspense fallback={null}>
        <Environment resolution={256} frames={1}>
          <Lightformer form="rect" intensity={1.6} color="#fff4e6" position={[0, 6, 2]} rotation={[-Math.PI / 2, 0, 0]} scale={[8, 4, 1]} />
          <Lightformer form="rect" intensity={0.5} color="#ffffff" position={[-6, 2, 3]} rotation={[0, Math.PI / 2, 0]} scale={[6, 6, 1]} />
          <Lightformer form="ring" intensity={2.5} color="#cfe9ff" position={[0, 3, -6]} scale={6} />
        </Environment>
      </Suspense>
      <primitive object={keyTarget} position={[0, 1.1, 0]} />
      <ambientLight intensity={0.05} />
      <spotLight position={[2.6, 5.5, 4.2]} angle={0.42} penumbra={0.85} intensity={45} color="#ffe2bd" target={keyTarget} />
      <spotLight position={[-4, 4, -5]} angle={0.5} penumbra={0.9} intensity={40} color="#bfe0ff" target={keyTarget} />
      <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, -0.001, 0]}>
        <planeGeometry args={[30, 30]} />
        <meshStandardMaterial color="#0c0c0d" roughness={0.85} />
      </mesh>
      <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, 0.001, 0]}>
        <circleGeometry args={[0.6, 48]} />
        <meshBasicMaterial map={shadow} transparent depthWrite={false} />
      </mesh>
      <Plant3D time={time} health={health} bloom={bloom} />
    </ThreeCanvas>
  );
};
