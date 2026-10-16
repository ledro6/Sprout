// Цвета, фигуры и движение — из приложения, а не на глаз.
// Источники: Design/Tokens.swift, Model/Pattern/Tint.swift,
// Design/Background/Shapes.swift, Design/Motion.swift, Model/Pattern/Front.swift.
import {spring} from 'remotion';

export type RGB = [number, number, number];

export const C = {
  // Palette.background / ink — светлая и тёмная тема
  bgLight: [255, 255, 255] as RGB,
  bgDark: [43, 46, 44] as RGB, // в тёмной белое — серое, не чёрное
  inkLight: [0, 0, 0] as RGB,
  inkDark: [238, 241, 237] as RGB,
  welcomeLight: [207, 248, 201] as RGB,
  welcomeDark: [18, 54, 13] as RGB,
  accent: [0, 136, 255] as RGB,
  green: [55, 181, 81] as RGB, // Palette.green — обводка логотипа
  water: [71, 181, 228] as RGB, // Palette.water — капли логотипа
  // Tint.green / Tint.blue
  palePattern: [207, 248, 201] as RGB,
  vividGreen: [10, 199, 51] as RGB,
  waveBlue: [0, 122, 255] as RGB,
  ember: [255, 45, 35] as RGB,
};

// Доли узора: покой 48% (светлая) и 16.5% (тёмная), гребень 46% и 62%.
export const SHARE = {restLight: 0.48, restDark: 0.165, waveLight: 0.46, waveDark: 0.62};

export const rgb = (c: RGB, a = 1) => `rgba(${c[0]},${c[1]},${c[2]},${a})`;
export const mix = (a: RGB, b: RGB, t: number): RGB => [
  a[0] + (b[0] - a[0]) * t,
  a[1] + (b[1] - a[1]) * t,
  a[2] + (b[2] - a[2]) * t,
];

// Motion.swift
export const M = {
  cheerSeconds: 2.4, // волна полива
  popSpan: 0.36, // доля прохода на одну фигурку
  popAmp: 0.15, // 1.15 на гребне
  popDip: 0.62,
  reach: 900, // Front.reach, pt
  logoSeconds: 0.85,
  logoLag: 0.13,
  logoScale: 0.7,
  textBlur: 8,
};

// Пружина SwiftUI .spring(duration:bounce:) в пересчёте на массу 1.
export const sui = (frame: number, fps: number, duration: number, bounce = 0) => {
  if (frame <= 0) return 0;
  const stiffness = Math.pow((2 * Math.PI) / duration, 2);
  const damping = (4 * Math.PI * (1 - bounce)) / duration;
  return spring({frame, fps, config: {mass: 1, stiffness, damping}});
};

export const clamp01 = (v: number) => Math.min(Math.max(v, 0), 1);
export const easeOut = (t: number) => 1 - Math.pow(1 - clamp01(t), 3);
export const easeInOut = (t: number) => {
  const x = clamp01(t);
  return x < 0.5 ? 4 * x * x * x : 1 - Math.pow(-2 * x + 2, 3) / 2;
};

// Фигурки узора: кривые из Shapes.swift.
export const LEAF =
  'M50.2067 0C50.2067 16.0251 38.9675 42.2327 25.1033 42.2327C11.2391 42.2327 0 16.0251 0 0C25.1033 0 11.2391 31.4466 25.1033 31.4466C38.9675 31.4466 25.1033 0 50.2067 0Z';
export const LEAF_C = [25.1033, 21.1164];
export const DROP =
  'M30.4193 27.0336C30.4193 35.4278 23.6097 42.2327 15.2097 42.2327C6.8096 42.2327 0 35.4278 0 27.0336C0 18.6393 14.513 0 15.2097 0C15.9063 0 30.4193 18.6393 30.4193 27.0336Z';
export const DROP_C = [15.2097, 21.1164];

// Цветок: пять кругов радиусом 6.8 через 72° на 8.4 от середины.
export const flowerCircles = () =>
  Array.from({length: 5}, (_, i) => {
    const a = -Math.PI / 2 + (i * 2 * Math.PI) / 5;
    return {x: Math.cos(a) * 8.4, y: Math.sin(a) * 8.4, r: 6.8};
  });

// Логотип: три листа контуром и две капли (Shapes.logoLeaves / logoDrops).
export const LOGO_BOX = {w: 74.9208, h: 137.5099, stroke: 7.4455};
export const LOGO_LEAVES: {pts: number[][]; closed: boolean}[] = [
  {pts: [[24.896, 70.2674], [0, 49.3268], [0, 85.8565], [24.896, 108.8912]], closed: true},
  {pts: [[24.896, 123.5496], [24.896, 108.8912]], closed: false},
  {pts: [[37.693, 63.5198], [37.693, 115.4059], [74.9207, 85.6238], [74.9207, 32.1089]], closed: true},
  {pts: [[37.693, 115.4059], [37.693, 137.5099]], closed: false},
  {pts: [[39.787, 13.9604], [23.4999, 27.2228], [23.4999, 50.0248], [26.99, 54.2129], [39.787, 43.2772]], closed: true},
];
export const LOGO_DROPS: number[][][] = [
  [[2.0941, 39.9268], [8.609, 26.5248], [15.5891, 39.9268], [8.609, 46.0694]],
  [[47.698, 23.2939], [59.1552, 0], [71.4307, 23.2939], [59.1552, 33.9703]],
];
// Снизу вверх, как растёт росток (SproutLogo.parts).
export const LOGO_PARTS = [
  {leaves: [2, 3], drops: [] as number[]},
  {leaves: [0, 1], drops: []},
  {leaves: [4], drops: []},
  {leaves: [], drops: [0]},
  {leaves: [], drops: [1]},
];

export const FONT = "'Inter Display', 'Inter', system-ui, sans-serif";
