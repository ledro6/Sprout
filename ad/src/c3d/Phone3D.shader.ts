// Материал экрана: без освещения, со скруглением по SDF и переходами между кадрами.
import * as THREE from 'three';

export type ScreenUniforms = {
  tA: {value: THREE.Texture | null};
  tB: {value: THREE.Texture | null};
  uKind: {value: number};
  uP: {value: number};
  uBlur: {value: number};
  uSize: {value: THREE.Vector2};
  uRadius: {value: number};
  uIsland: {value: number};
  uTaps: {value: THREE.Vector4[]};
  uTapN: {value: number};
};

export const TAP_SLOTS = 8;

const vert = /* glsl */ `
varying vec2 vUv;
void main() {
  vUv = uv;
  gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
}
`;

const frag = /* glsl */ `
uniform sampler2D tA;
uniform sampler2D tB;
uniform int uKind; // 0 cut, 1 blur, 2 slide, 3 zoom
uniform float uP;
uniform float uBlur;
uniform vec2 uSize;
uniform float uRadius;
uniform float uIsland;
uniform vec4 uTaps[${TAP_SLOTS}]; // xy — pt, z — возраст (с), w — волна
uniform int uTapN;
varying vec2 vUv;

const vec3 WAVE = vec3(0.0, 0.194, 1.0); // COL.waveBlue в линейном пространстве

float sdRRect(vec2 p, vec2 b, float r) {
  vec2 q = abs(p) - b + vec2(r);
  return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - r;
}

// pt (origin top-left) -> uv
vec2 ptUv(vec2 q) { return vec2(q.x / uSize.x, 1.0 - q.y / uSize.y); }

// Размытие кольцом из 16 отсчётов на уровне 0 (мипы здесь не работают).
vec3 smp(sampler2D t, vec2 uv, vec2 dX, vec2 dY) {
  return 0.25 * (textureLod(t, uv + dX + dY, 0.0).rgb + textureLod(t, uv - dX - dY, 0.0).rgb +
                 textureLod(t, uv + dX - dY, 0.0).rgb + textureLod(t, uv - dX + dY, 0.0).rgb);
}

vec3 blurTex(sampler2D t, vec2 uv, float r) {
  if (r < 1e-4) return smp(t, uv, vec2(0.7 / 1206.0, 0.0), vec2(0.0, 0.7 / 2622.0));
  float lod = max(0.0, log2(r * 1206.0 / 5.0));
  vec3 acc = vec3(0.0);
  for (int i = 0; i < 16; i++) {
    float fi = float(i);
    float a = fi * 2.39996323;
    float rr = sqrt((fi + 0.5) / 16.0) * r;
    acc += textureLod(t, uv + vec2(cos(a), sin(a)) * rr, lod).rgb;
  }
  return acc / 16.0;
}

void main() {
  vec2 pt = vec2(vUv.x, 1.0 - vUv.y) * uSize;
  float W = uSize.x;
  vec3 col;
  // Мипы и производные в этой среде дают чёрный экран: берём уровень 0
  // и сглаживаем четырьмя отсчётами на полтекселя.
  vec2 dX = vec2(0.7 / 1206.0, 0.0);
  vec2 dY = vec2(0.0, 0.7 / 2622.0);

  if (uKind == 0) {
    col = smp(tB, vUv, dX, dY);
  } else if (uKind == 1) {
    float s = smoothstep(0.0, 1.0, uP);
    col = mix(blurTex(tA, vUv, uBlur * s), blurTex(tB, vUv, uBlur * (1.0 - s)), s);
  } else if (uKind == 2) {
    float e = smoothstep(0.0, 1.0, uP);
    float xB = pt.x - (1.0 - e) * W; // новый кадр приходит справа
    float xA = xB + W;               // старый уезжает влево
    vec3 cB = smp(tB, ptUv(vec2(xB, pt.y)), dX, dY);
    vec3 cA = smp(tA, ptUv(vec2(xA, pt.y)), dX, dY);
    float sh = 1.0 - 0.45 * (1.0 - smoothstep(0.0, 28.0, -xB));
    col = xB >= 0.0 ? cB : cA * sh;
  } else {
    float e = smoothstep(0.0, 1.0, uP);
    float s = mix(0.35, 1.0, e);
    vec2 cc = uSize * 0.5;
    vec2 d0 = pt - cc;
    vec3 bg = smp(tA, vUv, dX, dY) * (1.0 - 0.5 * e);
    vec3 card = smp(tB, ptUv(d0 / s + cc), dX, dY);
    float dS = sdRRect(d0, uSize * 0.5 * s, uRadius * s);
    float aS = max(fwidth(dS), 0.001);
    float cm = (1.0 - smoothstep(-aS, aS, dS)) * smoothstep(0.0, 0.25, uP);
    col = mix(bg, card, cm);
  }

  // Касания: белая точка и кольцо; у касания с водой — волна по всему экрану.
  for (int i = 0; i < ${TAP_SLOTS}; i++) {
    if (i >= uTapN) break;
    vec4 tp = uTaps[i];
    float a = tp.z;
    if (a < 0.0) continue;
    float dist = length(pt - tp.xy);
    float pa = clamp(a / 0.5, 0.0, 1.0);
    float press = smoothstep(0.0, 0.05, a) * (1.0 - pa);
    float dotA = press * (1.0 - smoothstep(9.0, 14.0, dist)) * 0.7;
    float R = mix(10.0, 34.0, pa);
    float ringA = (1.0 - smoothstep(1.0, 2.2, abs(dist - R))) * (1.0 - pa) * 0.8;
    col = mix(col, vec3(1.0), clamp(dotA + ringA, 0.0, 1.0));

    if (tp.w > 0.5 && a < 2.4) {
      float pw = a / 2.4;
      float R2 = pw * 640.0;
      float life = pow(1.0 - pw, 1.3) * smoothstep(0.0, 0.08, a);
      float rim = exp(-pow((dist - R2) / 9.0, 2.0));
      float glow = exp(-pow((dist - R2) / 40.0, 2.0));
      float inside = (1.0 - smoothstep(R2 - 40.0, R2, dist)) * 0.5;
      // Смешиваем, а не складываем: на белом UI аддитивная синяя пропадает.
      col = mix(col, WAVE, clamp(life * (rim * 0.85 + glow * 0.3 + inside * 0.06), 0.0, 1.0));
    }
  }

  // Dynamic Island.
  if (uIsland > 0.5) {
    float di = sdRRect(pt - vec2(201.0, 29.0), vec2(62.0, 18.0), 18.0);
    col = mix(col, vec3(0.0), 1.0 - smoothstep(-0.6, 0.6, di));
  }

  vec2 c = uSize * 0.5;
  float d = sdRRect(pt - c, c, uRadius);
  float aa = max(fwidth(d), 0.001);
  float m = 1.0 - smoothstep(-aa, aa, d);
  gl_FragColor = linearToOutputTexel(vec4(col * m, 1.0));
}
`;

export const makeScreenMaterial = (size: [number, number], radius: number, island: boolean) => {
  const uniforms: ScreenUniforms = {
    tA: {value: null},
    tB: {value: null},
    uKind: {value: 0},
    uP: {value: 1},
    uBlur: {value: 0},
    uSize: {value: new THREE.Vector2(size[0], size[1])},
    uRadius: {value: radius},
    uIsland: {value: island ? 1 : 0},
    uTaps: {value: Array.from({length: TAP_SLOTS}, () => new THREE.Vector4(0, 0, -1, 0))},
    uTapN: {value: 0},
  };
  const mat = new THREE.ShaderMaterial({
    uniforms: uniforms as unknown as Record<string, {value: unknown}>,
    vertexShader: vert,
    fragmentShader: frag,
    toneMapped: false,
  });
  return mat;
};

export const screenUniforms = (m: THREE.ShaderMaterial) => m.uniforms as unknown as ScreenUniforms;
