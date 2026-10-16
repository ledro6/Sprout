import React from 'react';
import {staticFile} from 'remotion';
import {Ctx, Layout, Scene, at} from './Film';
import {SCREEN} from './parts/Phone';
import {Watch} from './parts/Text';
import {C, DROP, DROP_C, FONT, clamp01, rgb, sui} from './tokens';

// Точки касаний на экранах макета, pt (экран 402×874).
const TAP = {
  notifWatered: {x: 201, y: 444}, // «Полил» в уведомлении
  homeCard: {x: 101, y: 540}, // карточка «Баксик»
  plantPour: {x: 201, y: 510}, // «Полить сейчас»
  askChip: {x: 124, y: 556}, // «Кого полить сегодня?»
  invent: {x: 304, y: 744}, // «Придумать»
};

// Плавное покачивание вокруг позы — телефон «живой» в руке камеры.
const drift = (t: number, amp = 1) => ({
  ry: Math.sin(t * 0.9) * 6 * amp,
  rx: Math.sin(t * 0.7 + 1) * 3 * amp,
});

// Орбиты планетария, приподнятые над экраном в объёме.
const Orbits = ({L, t}: Ctx) => {
  const s = L.base;
  const cx = 200 * s;
  const cy = 292 * s;
  const up = sui(t * 30, 30, 0.8, 0.15);
  const rings = [
    {r: 62, z: 50, speed: 1.4, col: C.ember},
    {r: 104, z: 90, speed: 0.8, col: C.vividGreen},
    {r: 146, z: 130, speed: 0.5, col: C.water},
  ];
  return (
    <>
      {rings.map((rg, i) => (
        <div
          key={i}
          style={{
            position: 'absolute',
            left: cx - rg.r * s,
            top: cy - rg.r * s,
            width: 2 * rg.r * s,
            height: 2 * rg.r * s,
            borderRadius: '50%',
            border: `${2 * s}px solid rgba(255,255,255,${0.5 * up})`,
            transform: `translateZ(${rg.z * s * up}px) rotateZ(${t * rg.speed * 60 + i * 70}deg)`,
          }}
        >
          <div
            style={{
              position: 'absolute',
              left: rg.r * s - 11 * s,
              top: -11 * s,
              width: 22 * s,
              height: 22 * s,
              borderRadius: '50%',
              background: rgb(rg.col),
              boxShadow: `0 0 ${18 * s}px ${rgb(rg.col, 0.9)}`,
              opacity: up,
            }}
          />
        </div>
      ))}
    </>
  );
};

const watchFront = ({L, t}: Ctx) => {
  const enter = sui(t * 30 - 6, 30, 0.6, 0.2);
  const wide = L.kind !== 'tall';
  const x = wide ? L.phone.x + 0.33 * SCREEN.h * L.base : L.phone.x + 0.26 * SCREEN.h * L.base;
  const y = L.phone.y + (wide ? 0.08 : 0.12) * SCREEN.h * L.base + (1 - enter) * 300;
  return (
    <div style={{opacity: clamp01(enter * 1.5)}}>
      <Watch x={x} y={y} s={L.base * 1.05} ry={-16 + Math.sin(t) * 4} rx={6} t={t} src={staticFile('scr/watch.jpg')} />
    </div>
  );
};

// ---------- B. «Он тебе пишет» ----------
export const scenesB = (cut: 'full' | 'short' = 'full'): Scene[] => {
  const hook: Scene = {
    id: 'hook',
    dur: cut === 'short' ? 2.5 : 3,
    caption: 'Баксик просит воды',
    sub: 'Это Sprout напоминает о поливе',
    screens: [{at: 0, src: 'notif_water', kind: 'cut'}],
    pose: (t, L) => at(L, {dy: 0.06, s: 0.98, rx: 52 - t * 2, rz: -10 + t, ry: 4}),
    plant: [{at: 0, health: 0, bloom: 0}],
    noWave: true,
  };
  const notif: Scene = {
    id: 'notif',
    dur: cut === 'short' ? 2.6 : 3,
    caption: 'Полить — прямо\nиз уведомления',
    sub: 'Не открывая приложение',
    taps: [{at: 0.8, ...TAP.notifWatered, wave: true, world: true}],
    pose: (t, L) => at(L, {dy: 0.02, s: 1.02, rx: 40 - t * 3, rz: -6 + t, ry: 2}),
    plant: [{at: 1.0, health: 0.55}],
  };
  const home: Scene = {
    id: 'home',
    dur: cut === 'short' ? 2.6 : 4,
    caption: 'Весь сад —\nна одном экране',
    sub: 'Кто хочет пить — светится красным',
    screens: [{at: 0.2, src: 'home_light', kind: 'blur'}],
    taps: [{at: cut === 'short' ? 2.1 : 3.4, ...TAP.homeCard}],
    pose: (t, L) => at(L, {ry: -16 + t * 6, rx: 4, ...{}}),
  };
  const water: Scene = {
    id: 'water',
    dur: cut === 'short' ? 3.6 : 5,
    caption: 'Одно касание —\nи волна',
    sub: 'Полив бежит волной по всему саду',
    screens: [
      {at: 0, src: 'plant', kind: 'zoom', ox: TAP.homeCard.x, oy: TAP.homeCard.y},
      {at: 1.45, src: 'plant_watered', kind: 'blur'},
    ],
    taps: [{at: 1.1, ...TAP.plantPour, wave: true, world: true}],
    pose: (t, L) => at(L, {s: 1.02, ...drift(t, 0.8)}),
    plant: [{at: 1.3, health: 1}, {at: 1.7, bloom: 1}],
  };
  const ask: Scene = {
    id: 'ask',
    dur: 6,
    caption: 'Спросите сад\nобычными словами',
    sub: 'Отвечает модель Apple — прямо на телефоне, без сети',
    screens: [
      {at: 0, src: 'ask', kind: 'blur'},
      {at: 1.6, src: 'ask_think', kind: 'blur'},
      {at: 3.4, src: 'ask_talk', kind: 'blur'},
    ],
    taps: [{at: 1.2, ...TAP.askChip}],
    pose: (t, L) => at(L, {s: 1.04, ry: 12 - t * 3, rx: 3}),
  };
  const diag: Scene = {
    id: 'diag',
    dur: 5,
    caption: '«Что с ним?» —\nпо фото',
    sub: 'Разберёт снимок и составит план лечения',
    screens: [
      {at: 0, src: 'diag_scan', kind: 'blur'},
      {at: 1.6, src: 'diag', kind: 'blur'},
      {at: 3.3, src: 'treat', kind: 'blur'},
    ],
    pose: (t, L) => at(L, {ry: -10 + t * 3, rx: 2}),
  };
  const add: Scene = {
    id: 'add',
    dur: 5,
    caption: 'Узнает вид по фото',
    sub: 'Vision подскажет срок полива, а кличку придумает модель Apple',
    screens: [
      {at: 0, src: 'add_frame', kind: 'blur'},
      {at: 1.3, src: 'add_scan', kind: 'blur'},
      {at: 2.7, src: 'add', kind: 'blur'},
    ],
    taps: [{at: 3.7, ...TAP.invent}],
    pose: (t, L) => at(L, {ry: 10 - t * 3, rx: 3}),
  };
  const portrait: Scene = {
    id: 'portrait',
    dur: 3,
    caption: 'Нарисует портрет',
    sub: 'Image Playground — по фото растения',
    screens: [{at: 0, src: 'portrait', kind: 'blur'}],
    pose: (t, L) => at(L, {s: 1.02, ...drift(t)}),
  };
  const planet: Scene = {
    id: 'planet',
    dur: 3.5,
    caption: 'Сад как планеты',
    sub: 'Один оборот — один срок полива',
    screens: [{at: 0, src: 'planetarium', kind: 'blur'}],
    pose: (t, L) => at(L, {dy: 0.05, s: 0.96, rx: 38, rz: -8 + t * 3}),
    above: (c) => <Orbits {...c} />,
  };
  const ar: Scene = {
    id: 'ar',
    dur: 3,
    caption: 'Полейте в AR',
    sub: 'Модель растения и вода из лейки',
    screens: [{at: 0, src: 'ar_water', kind: 'blur'}],
    pose: (t, L) => at(L, {ry: -18 + t * 5, rx: 4}),
  };
  const watch: Scene = {
    id: 'watch',
    dur: 3.5,
    caption: 'И с запястья',
    sub: 'Apple Watch: кольцо влажности и «Полить»',
    screens: [{at: 0, src: 'home_light', kind: 'blur'}],
    pose: (t, L) => at(L, {dx: -0.12, s: 0.82, ry: 18, rx: 3}),
    front: watchFront,
  };
  const family: Scene = {
    id: 'family',
    dur: 3.5,
    caption: 'С семьёй и друзьями',
    sub: 'Общий сад в iCloud и челлендж перепиской с кодом',
    screens: [
      {at: 0, src: 'family', kind: 'blur'},
      {at: 1.8, src: 'compare', kind: 'slide'},
    ],
    pose: (t, L) => at(L, {ry: -8 + t * 4, rx: 2}),
  };
  const privacy: Scene = {
    id: 'privacy',
    dur: 3,
    caption: 'Без аккаунта',
    sub: 'Своего сервера нет. Нейросети работают на телефоне',
    screens: [{at: 0, src: 'lock', kind: 'blur'}],
    pose: (t, L) => at(L, {s: 1.02, ...drift(t, 0.6)}),
  };
  const night: Scene = {
    id: 'night',
    dur: 2.5,
    caption: 'Днём и ночью',
    sub: 'В тёмной теме белое становится серым',
    screens: [{at: 0.25, src: 'home_dark', kind: 'blur'}],
    flip: {at: 0.15, to: 'dark'},
    pose: (t, L) => at(L, {ry: 10 - t * 6, rx: 3}),
  };
  const end: Scene = {id: 'end', dur: cut === 'short' ? 3.7 : 5, end: true, pose: (t, L) => at(L, {s: 0.9})};

  if (cut === 'short') return [hook, notif, home, water, end];
  return [hook, notif, home, water, ask, diag, add, portrait, planet, ar, watch, family, privacy, night, end];
};

// ---------- C. «Сад за год» — кинетическая типографика ----------
const fitSize = (L: Layout, text: string) => {
  const longest = Math.max(...text.split('\n').map((l) => l.length));
  return Math.min(L.word.size, L.word.w / (0.6 * longest));
};

// Слово ударом: проступает из размытия, садится с отскоком, уходит размытием.
const Word = ({L, t, fps, dark}: Ctx, text: string, dur: number, sub?: string) => {
  const size = fitSize(L, text);
  const inP = sui(t * fps, fps, 0.42, 0.3);
  const out = clamp01((t - (dur - 0.28)) / 0.28);
  const ink = dark ? C.inkDark : C.inkLight;
  return (
    <div
      style={{
        position: 'absolute',
        left: L.word.x,
        top: L.word.y,
        width: L.word.w,
        textAlign: L.word.align,
        fontFamily: FONT,
        color: rgb(ink),
        opacity: clamp01(t / 0.15) * (1 - out),
        filter: `blur(${(1 - clamp01(t / 0.3)) * 18 + out * 16}px)`,
        transform: `scale(${1.25 - 0.25 * inP}) translateY(${-out * 40}px)`,
        transformOrigin: L.word.align === 'left' ? '0% 50%' : '50% 50%',
      }}
    >
      <div style={{fontSize: size, fontWeight: 900, lineHeight: 0.95, letterSpacing: -size * 0.04, whiteSpace: 'pre-line'}}>
        {text}
      </div>
      {sub && (
        <div style={{marginTop: size * 0.18, fontSize: Math.max(34, size * 0.2), fontWeight: 600, opacity: 0.6}}>{sub}</div>
      )}
    </div>
  );
};

const HookWords = ({L, t, fps, dark}: Ctx) => {
  const words = ['Ты', 'забыл', 'полить'];
  const ink = dark ? C.inkDark : C.inkLight;
  const size = Math.min(L.word.size * 1.25, L.kind === 'tall' ? 270 : 220);
  const fall = clamp01((t - 1.55) / 0.7);
  const dropY = L.word.y + size * 3.0 + fall * fall * (L.plant.y - L.plant.h * 0.55 - L.word.y - size * 3);
  return (
    <>
      <div
        style={{
          position: 'absolute',
          left: L.word.x,
          top: L.word.y,
          width: L.word.w,
          textAlign: L.word.align,
          fontFamily: FONT,
          color: rgb(ink),
          fontSize: size,
          fontWeight: 900,
          lineHeight: 0.98,
          letterSpacing: -size * 0.045,
        }}
      >
        {words.map((w, i) => {
          const p = sui((t - i * 0.42) * fps, fps, 0.38, 0.32);
          return (
            <div
              key={i}
              style={{
                opacity: clamp01((t - i * 0.42) / 0.12),
                transform: `scale(${1.35 - 0.35 * p})`,
                transformOrigin: L.word.align === 'left' ? '0% 50%' : '50% 50%',
                filter: `blur(${(1 - clamp01((t - i * 0.42) / 0.25)) * 16}px)`,
              }}
            >
              {w}
            </div>
          );
        })}
      </div>
      {t > 1.4 && fall < 1 && (
        <svg
          width={60}
          height={84}
          viewBox="0 0 30.42 42.23"
          style={{
            position: 'absolute',
            left: (L.word.align === 'center' ? L.word.x + L.word.w / 2 : L.plant.x) - 30,
            top: dropY,
            opacity: clamp01((t - 1.4) / 0.15),
          }}
        >
          <path d={DROP} fill={rgb(C.water)} transform={`translate(${DROP_C[0] - 15.21} 0)`} />
        </svg>
      )}
    </>
  );
};

type WordSpec = {word: string; sub?: string; dur: number; screens: Scene['screens']; taps?: Scene['taps']; pose?: Scene['pose']; plant?: Scene['plant']; above?: Scene['above']; front?: Scene['front']};

export const scenesC = (cut: 'full' | 'short' = 'full'): Scene[] => {
  const low = (L: Layout) => (L.kind === 'tall' ? 0.09 : 0);
  const sc = (L: Layout) => (L.kind === 'tall' ? 0.88 : 1);
  const w = (spec: WordSpec): Scene => ({
    id: spec.word,
    dur: spec.dur,
    screens: spec.screens,
    taps: spec.taps,
    plant: spec.plant,
    above: spec.above,
    pose: spec.pose ?? ((t, L) => at(L, {dy: low(L), s: sc(L), ry: 12 - t * 6, rx: 3})),
    front: (c) => (
      <>
        {spec.front?.(c)}
        {Word(c, spec.word, spec.dur, spec.sub)}
      </>
    ),
  });

  const hook: Scene = {
    id: 'hook',
    dur: 2.6,
    phoneHidden: true,
    noWave: true,
    plant: [{at: 0, health: 0, bloom: 0}],
    front: (c) => <HookWords {...c} />,
  };
  const remember = w({
    word: 'Sprout\nпомнит',
    dur: 4,
    screens: [
      {at: 0, src: 'plant', kind: 'blur'},
      {at: 1.6, src: 'plant_watered', kind: 'blur'},
    ],
    taps: [{at: 1.25, ...TAP.plantPour, wave: true, world: true}],
    plant: [{at: 1.4, health: 1}, {at: 1.8, bloom: 1}],
    pose: (t, L) => at(L, {dy: low(L), s: sc(L), ...drift(t)}),
  });
  const greets = w({word: 'Встречает', sub: 'Карточка дня: кто ждёт воды', dur: 3, screens: [{at: 0, src: 'bedroom', kind: 'blur'}]});
  const knows = w({
    word: 'Узнаёт',
    sub: 'Вид и срок полива — по фото',
    dur: 3,
    screens: [
      {at: 0, src: 'add_frame', kind: 'blur'},
      {at: 1.3, src: 'add_scan', kind: 'blur'},
    ],
  });
  const names = w({
    word: 'Называет',
    sub: 'Кличку придумает модель Apple',
    dur: 2.6,
    screens: [{at: 0, src: 'add', kind: 'blur'}],
    taps: [{at: 1.2, ...TAP.invent}],
  });
  const heals = w({
    word: 'Лечит',
    sub: '«Что с ним?» и план лечения',
    dur: 3.4,
    screens: [
      {at: 0, src: 'diag', kind: 'blur'},
      {at: 1.7, src: 'treat', kind: 'blur'},
    ],
  });
  const answers = w({
    word: 'Отвечает',
    sub: 'Спросите сад — ответит сам телефон',
    dur: cut === 'short' ? 3.4 : 3.6,
    screens: [
      {at: 0, src: 'ask_think', kind: 'blur'},
      {at: 1.6, src: 'ask_talk', kind: 'blur'},
    ],
  });
  const draws = w({word: 'Рисует', sub: 'Портрет растения', dur: 2.6, screens: [{at: 0, src: 'portrait', kind: 'blur'}]});
  const counts = w({word: 'Считает', sub: 'Статистика сада', dur: 2.6, screens: [{at: 0, src: 'stats', kind: 'blur'}]});
  const orbits = w({
    word: 'Кружит',
    sub: 'Планетарий: сад как планеты',
    dur: 3,
    screens: [{at: 0, src: 'planetarium', kind: 'blur'}],
    pose: (t, L) => at(L, {dy: low(L) + 0.04, s: sc(L) * 0.95, rx: 38, rz: -8 + t * 3}),
    above: (c) => <Orbits {...c} />,
  });
  const praises = w({word: 'Хвалит', sub: 'Награды и уровни садовника', dur: 2.6, screens: [{at: 0, src: 'awards', kind: 'blur'}]});
  const ar = w({word: 'Выходит\nв комнату', sub: 'AR и вода из лейки', dur: 3, screens: [{at: 0, src: 'ar_water', kind: 'blur'}]});
  const wrist = w({
    word: 'На запястье',
    sub: 'Apple Watch',
    dur: 3,
    screens: [{at: 0, src: 'home_light', kind: 'blur'}],
    pose: (t, L) => at(L, {dx: -0.12, dy: low(L), s: sc(L) * 0.82, ry: 18, rx: 3}),
    front: watchFront,
  });
  const family = w({
    word: 'Для всей\nсемьи',
    sub: 'Общий сад в iCloud и челлендж с друзьями',
    dur: 3,
    screens: [
      {at: 0, src: 'family', kind: 'blur'},
      {at: 1.6, src: 'compare', kind: 'slide'},
    ],
  });
  const noAccount = w({word: 'Без\nаккаунта', sub: 'Нейросети — на телефоне', dur: 3, screens: [{at: 0, src: 'lock', kind: 'blur'}]});
  const recap = w({word: 'Итоги\nгода', sub: 'Как жил ваш сад', dur: 3, screens: [{at: 0, src: 'recap_intro', kind: 'blur'}]});
  const end: Scene = {id: 'end', dur: cut === 'short' ? 5 : 5, end: true};

  if (cut === 'short') return [hook, remember, answers, end];
  return [hook, remember, greets, knows, names, heals, answers, draws, counts, orbits, praises, ar, wrist, family, noAccount, recap, end];
};

