// Общий контракт ролика C (3D, 9:16). Тайминги — только здесь.
import {useMemo} from 'react';
import {staticFile} from 'remotion';
import {SRGBColorSpace, Texture, TextureLoader} from 'three';

export const FPS = 30;
export const W = 1080;
export const H = 1920;

// ---------- Сцены ----------
export type ScreenCue = {
  at: number; // секунды от начала сцены
  src: ScreenName;
  kind?: 'blur' | 'zoom' | 'slide' | 'cut';
};
// Касание на экране, pt (экран 402×874, начало — левый верхний угол).
export type TapCue = {at: number; x: number; y: number; water?: boolean};

export type SceneSpec = {
  id: string;
  dur: number;
  word?: string; // крупное слово (\n — перенос)
  sub?: string; // пояснение мелко
  screens?: ScreenCue[];
  taps?: TapCue[];
  phone?: boolean; // false — телефона нет в кадре
  watch?: boolean;
  orbits?: boolean;
  end?: boolean;
};

export const SCENES: SceneSpec[] = [
  {id: 'hook', dur: 2.4, word: 'Ты\nзабыл\nполить', phone: false},
  {
    id: 'remember',
    dur: 3.8,
    word: 'Sprout\nпомнит',
    screens: [
      {at: 0, src: 'plant'},
      {at: 1.7, src: 'plant_watered', kind: 'blur'},
    ],
    taps: [{at: 1.35, x: 201, y: 510, water: true}],
  },
  {id: 'greets', dur: 2.4, word: 'Встречает', sub: 'Карточка дня: кто ждёт воды', screens: [{at: 0, src: 'bedroom', kind: 'blur'}]},
  {
    id: 'knows',
    dur: 2.6,
    word: 'Узнаёт',
    sub: 'Vision: вид и срок полива по фото',
    screens: [
      {at: 0, src: 'add_frame', kind: 'blur'},
      {at: 1.2, src: 'add_scan', kind: 'blur'},
    ],
  },
  {
    id: 'names',
    dur: 2.2,
    word: 'Называет',
    sub: 'Кличку придумает модель Apple',
    screens: [{at: 0, src: 'add', kind: 'blur'}],
    taps: [{at: 1.0, x: 304, y: 744}],
  },
  {
    id: 'heals',
    dur: 2.8,
    word: 'Лечит',
    sub: '«Что с ним?» и план лечения',
    screens: [
      {at: 0, src: 'diag', kind: 'blur'},
      {at: 1.4, src: 'treat', kind: 'blur'},
    ],
  },
  {
    id: 'answers',
    dur: 3.0,
    word: 'Отвечает',
    sub: 'Спросите сад — ответит сам телефон',
    screens: [
      {at: 0, src: 'ask_think', kind: 'blur'},
      {at: 1.3, src: 'ask_talk', kind: 'blur'},
    ],
  },
  {id: 'draws', dur: 2.2, word: 'Рисует', sub: 'Портрет растения в Image Playground', screens: [{at: 0, src: 'portrait', kind: 'blur'}]},
  {id: 'orbits', dur: 2.6, word: 'Кружит', sub: 'Планетарий: сад как планеты', screens: [{at: 0, src: 'planetarium', kind: 'blur'}], orbits: true},
  {id: 'wrist', dur: 2.4, word: 'На запястье', sub: 'Apple Watch', screens: [{at: 0, src: 'home_light', kind: 'blur'}], watch: true},
  {
    id: 'family',
    dur: 2.4,
    word: 'Для всей\nсемьи',
    sub: 'Общий сад в iCloud и челлендж с друзьями',
    screens: [
      {at: 0, src: 'family', kind: 'blur'},
      {at: 1.2, src: 'compare', kind: 'slide'},
    ],
  },
  {id: 'private', dur: 2.2, word: 'Без\nаккаунта', sub: 'Нейросети — на телефоне', screens: [{at: 0, src: 'lock', kind: 'blur'}]},
  {id: 'end', dur: 4.0, phone: false, end: true},
];

export const sceneStarts = (() => {
  let acc = 0;
  return SCENES.map((s) => {
    const v = acc;
    acc += s.dur;
    return v;
  });
})();
export const TOTAL = SCENES.reduce((a, s) => a + s.dur, 0);
export const DURATION_FRAMES = Math.round(TOTAL * FPS);

export const sceneAt = (t: number) => {
  let i = 0;
  for (let k = 0; k < SCENES.length; k++) if (sceneStarts[k] <= t) i = k;
  return {index: i, scene: SCENES[i], local: t - sceneStarts[i], start: sceneStarts[i]};
};

// Все кадры экрана и касания — в глобальных секундах.
export const GLOBAL_SCREENS: {at: number; src: ScreenName; kind: NonNullable<ScreenCue['kind']>}[] = SCENES.flatMap(
  (s, i) => (s.screens ?? []).map((c) => ({at: c.at + sceneStarts[i], src: c.src, kind: c.kind ?? 'cut'})),
);
export const GLOBAL_TAPS: TapCue[] = SCENES.flatMap((s, i) => (s.taps ?? []).map((c) => ({...c, at: c.at + sceneStarts[i]})));

// ---------- Мир ----------
// Единицы сцены — «метры». Ось Y вверх, камера смотрит в −Z.
export const PHONE = {
  height: 1.6, // корпус iPhone: 71.9 × 150 × 8.75 мм в масштабе
  width: 1.6 * (71.9 / 150),
  depth: 1.6 * (8.75 / 150),
  screenPt: {w: 402, h: 874, r: 55}, // экран макета, pt
};
export const FLOOR_Y = -1.25;

// ---------- Цвета приложения (Design/Tokens.swift, Tint.swift) ----------
export const COL = {
  green: '#37b551', // Palette.green — логотип
  water: '#47b5e4', // Palette.water — капли логотипа
  accent: '#0088ff',
  waveBlue: '#007aff', // Tint.blue.vivid — гребень волны
  vividGreen: '#0ac733', // Tint.green.vivid
  pale: '#cff8c9', // Tint.green.pale
  bgDark: '#2b2e2c', // тёмная тема: серый, не чёрный
  welcomeDark: '#12360d',
};

// ---------- Текстуры экранов ----------
export type ScreenName =
  | 'plant'
  | 'plant_watered'
  | 'bedroom'
  | 'add_frame'
  | 'add_scan'
  | 'add'
  | 'diag'
  | 'treat'
  | 'ask_think'
  | 'ask_talk'
  | 'portrait'
  | 'planetarium'
  | 'home_light'
  | 'family'
  | 'compare'
  | 'lock'
  | 'watch';

export const ALL_SCREENS: ScreenName[] = [
  'plant',
  'plant_watered',
  'bedroom',
  'add_frame',
  'add_scan',
  'add',
  'diag',
  'treat',
  'ask_think',
  'ask_talk',
  'portrait',
  'planetarium',
  'home_light',
  'family',
  'compare',
  'lock',
  'watch',
];

// Грузит текстуры один раз и держит рендер, пока всё не загрузится.
// Экраны — 1206×2622 (3×), часы — 615×753.
export const useScreenTextures = (): Record<ScreenName, Texture> =>
  // Держать снимок до загрузки — забота того, кто рисует холст (см. Warm в Film3D):
  // без дорисовки после загрузки экран всё равно вышел бы чёрным.
  useMemo(() => {
    const loader = new TextureLoader();
    const out = {} as Record<ScreenName, Texture>;
    for (const n of ALL_SCREENS) {
      const t = loader.load(staticFile(`scr/${n}.jpg`));
      t.colorSpace = SRGBColorSpace;
      t.anisotropy = 8;
      out[n] = t;
    }
    return out;
  }, []);

// ---------- Движение ----------
export {sui, clamp01, easeOut, easeInOut, LEAF, DROP, LEAF_C, DROP_C, LOGO_BOX, LOGO_LEAVES, LOGO_DROPS, LOGO_PARTS, M} from '../tokens';
