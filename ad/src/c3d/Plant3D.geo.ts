// Геометрия растения: лист, жилка, черенок, лепесток, горшок. Чистые функции без React.
import * as THREE from 'three';

export const clamp01 = (v: number) => Math.min(Math.max(v, 0), 1);
export const lerp = (a: number, b: number, t: number) => a + (b - a) * t;
export const smooth = (x: number) => {
  const t = clamp01(x);
  return t * t * (3 - 2 * t);
};
export const easeOutCubic = (x: number) => 1 - Math.pow(1 - clamp01(x), 3);
// Перелёт при раскрытии: лепестки чуть проскакивают и возвращаются.
export const easeOutBack = (x: number, c = 1.1) => {
  const t = clamp01(x) - 1;
  return 1 + (c + 1) * t * t * t + c * t * t;
};

// Детерминированный PRNG — никакого Math.random в кадре.
export const mulberry32 = (seed: number) => {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
};

// Лист в единичных координатах: основание в начале, кончик по −Y (длина 1), нормаль +Z.
const LEAF_S = 24; // сегментов по длине
const LEAF_U = 16; // сегментов поперёк

// Полярная сетка (для лепестков): кольца от центра, цикл по углу.
const gridIndices = (K: number, N: number) => {
  const idx: number[] = [];
  for (let k = 0; k < K; k++)
    for (let j = 0; j < N; j++) {
      const a = k * N + j;
      const b = k * N + ((j + 1) % N);
      const c = (k + 1) * N + j;
      const d = (k + 1) * N + ((j + 1) % N);
      idx.push(a, c, b, b, c, d);
    }
  return idx;
};

// Прямоугольная сетка (для листа): без цикла по углу.
const planeIndices = (S: number, U: number) => {
  const idx: number[] = [];
  const row = U + 1;
  for (let i = 0; i < S; i++)
    for (let j = 0; j < U; j++) {
      const a = i * row + j;
      const c = (i + 1) * row + j;
      idx.push(a, c, a + 1, a + 1, c, c + 1);
    }
  return idx;
};

// Ширина половины листа от основания (s=0) к кончику (s=1): V-выемка у черенка,
// два округлых «лопастя» у основания и острый кончик.
const leafWidth = (s: number) => 0.36 * Math.pow(Math.sin(Math.PI * Math.pow(s, 0.55)), 0.7) * Math.pow(1 - s, 0.55);

// h: 0 — сухой (свернут вниз, провисает), 1 — здоровый (плоский, лёгкая волна).
const leafParams = (h: number) => ({
  droop: lerp(0.22, 0.04, h),
  cup: lerp(-0.9, 0.25, h),
  wave: lerp(0.05, 0.02, h),
});

export const buildLeaf = (h: number) => {
  const {droop, cup, wave} = leafParams(h);
  const pos: number[] = [];
  const uv: number[] = [];
  for (let i = 0; i <= LEAF_S; i++) {
    const s = i / LEAF_S;
    const W = leafWidth(s);
    for (let j = 0; j <= LEAF_U; j++) {
      const u = (j / LEAF_U) * 2 - 1;
      const x = u * W;
      // Гребень жилки и волна по краю — видны при боковом свете.
      const z = cup * u * u * W + 0.06 * Math.exp(-((x / 0.02) ** 2)) - droop * s * s + wave * u * u * Math.sin(s * 12);
      pos.push(x, -s, z);
      uv.push(u * 0.5 + 0.5, s);
    }
  }
  const g = new THREE.BufferGeometry();
  g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
  g.setAttribute('uv', new THREE.Float32BufferAttribute(uv, 2));
  g.setIndex(planeIndices(LEAF_S, LEAF_U));
  g.computeVertexNormals();
  return g;
};

// Изнанка: та же геометрия, но нормали развёрнуты — свет падает на неё как на обратную сторону.
export const negateNormals = (g: THREE.BufferGeometry) => {
  const c = g.clone();
  const n = c.attributes.normal as THREE.BufferAttribute;
  for (let i = 0; i < n.count; i++) n.setXYZ(i, -n.getX(i), -n.getY(i), -n.getZ(i));
  n.needsUpdate = true;
  return c;
};

// Средняя жилка: трубка по гребню листа.
export const buildMidrib = (h: number) => {
  const {droop} = leafParams(h);
  const pts: THREE.Vector3[] = [];
  for (let i = 0; i <= 12; i++) {
    const s = i / 12;
    pts.push(new THREE.Vector3(0, -s, 0.06 - droop * s * s));
  }
  return new THREE.TubeGeometry(new THREE.CatmullRomCurve3(pts), 24, 0.009, 6, false);
};

export const buildTube = (pts: THREE.Vector3[], radius: number, segs = 20) =>
  new THREE.TubeGeometry(new THREE.CatmullRomCurve3(pts), segs, radius, 7, false);

// Текстура листа: боковые жилки и средняя жилка; множится на цвет материала.
// UV листа: u — поперёк (0.5 — ось), v — от выемки (0) к кончику (1).
export const makeLeafMap = () => {
  const S = 512;
  const c = document.createElement('canvas');
  c.width = S;
  c.height = S;
  const g = c.getContext('2d')!;
  const grd = g.createRadialGradient(S / 2, S * 0.45, S * 0.05, S / 2, S * 0.5, S * 0.62);
  grd.addColorStop(0, '#ffffff');
  grd.addColorStop(1, '#8fa895');
  g.fillStyle = grd;
  g.fillRect(0, 0, S, S);
  const X = (u: number) => u * S;
  const Y = (v: number) => (1 - v) * S;
  g.lineCap = 'round';
  g.strokeStyle = 'rgba(225,245,225,0.55)';
  g.lineWidth = S * 0.006;
  for (let i = 0; i < 7; i++) {
    const v = 0.12 + i * 0.12;
    for (const sd of [-1, 1]) {
      g.beginPath();
      g.moveTo(X(0.5), Y(v));
      g.quadraticCurveTo(X(0.5 + sd * 0.2), Y(v + 0.02), X(0.5 + sd * 0.36), Y(v + 0.14));
      g.stroke();
    }
  }
  g.strokeStyle = 'rgba(240,255,240,0.8)';
  g.lineWidth = S * 0.012;
  g.beginPath();
  g.moveTo(X(0.5), Y(0));
  g.lineTo(X(0.5), Y(0.97));
  g.stroke();
  const tex = new THREE.CanvasTexture(c);
  tex.colorSpace = THREE.SRGBColorSpace;
  tex.anisotropy = 8;
  return tex;
};

// Горшок: матовый графит и отдельное глянцевое кольцо.
export const buildPot = () => {
  const body = new THREE.LatheGeometry(
    [
      [0, 0], [0.2, 0], [0.27, 0.006], [0.33, 0.04], [0.36, 0.12], [0.373, 0.3],
      [0.378, 0.48], [0.377, 0.64], [0.376, 0.66], [0.345, 0.66], [0.338, 0.6], [0, 0.6],
    ].map(([x, y]) => new THREE.Vector2(x, y)),
    64,
  );
  const rim = new THREE.LatheGeometry(
    [[0.374, 0.652], [0.384, 0.672], [0.386, 0.7], [0.352, 0.7], [0.344, 0.664]].map(([x, y]) => new THREE.Vector2(x, y)),
    64,
  );
  return {body, rim};
};

// Земля: плоский круг с мелким шумом.
export const buildSoil = () => {
  const g = new THREE.CircleGeometry(0.345, 48);
  g.rotateX(-Math.PI / 2);
  const p = g.attributes.position as THREE.BufferAttribute;
  for (let i = 0; i < p.count; i++) {
    const x = p.getX(i);
    const z = p.getZ(i);
    p.setY(i, 0.6 + 0.012 * Math.sin(x * 29 + z * 13) * Math.cos(z * 17 - x * 5) + 0.008 * Math.sin(x * 61 - z * 43));
  }
  g.computeVertexNormals();
  return g;
};

// Лепесток: диск в плоскости хаба (радиус R, центр на расстоянии D), края чуть подняты.
export const buildPetal = (R: number, D: number, cup: number) => {
  const K = 7;
  const N = 36;
  const c0 = new THREE.Color('#ff5c80');
  const c1 = new THREE.Color('#ffa0ba');
  const pos: number[] = [];
  const col: number[] = [];
  for (let k = 0; k <= K; k++) {
    const f = k / K;
    const c = c0.clone().lerp(c1, Math.pow(f, 1.2));
    for (let j = 0; j < N; j++) {
      const a = (j / N) * Math.PI * 2;
      const rk = R * f;
      pos.push(rk * Math.cos(a), D + rk * Math.sin(a), cup * f * f);
      col.push(c.r, c.g, c.b);
    }
  }
  const g = new THREE.BufferGeometry();
  g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
  g.setAttribute('color', new THREE.Float32BufferAttribute(col, 3));
  g.setIndex(gridIndices(K, N));
  g.computeVertexNormals();
  return g;
};

// Мягкая тень под горшком (контактная, без теней в рендере).
export const makeShadowMap = () => {
  const S = 256;
  const c = document.createElement('canvas');
  c.width = S;
  c.height = S;
  const g = c.getContext('2d')!;
  const grd = g.createRadialGradient(S / 2, S / 2, 0, S / 2, S / 2, S / 2);
  grd.addColorStop(0, 'rgba(0,0,0,0.9)');
  grd.addColorStop(0.5, 'rgba(0,0,0,0.5)');
  grd.addColorStop(1, 'rgba(0,0,0,0)');
  g.fillStyle = grd;
  g.fillRect(0, 0, S, S);
  return new THREE.CanvasTexture(c);
};
