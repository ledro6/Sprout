import React from 'react';
import {RGB, flowerCircles, mix, rgb, sui} from '../tokens';

// Растение за телефоном. Состояние — «здоровье» (поник → стоит) и «цветение».
// Цветок — фигурка узора: пять кругов через 72° (Shapes.flower).
export type PlantKey = {at: number; health?: number; bloom?: number};

const DRY_LEAF: RGB = [170, 152, 88];
const LEAF: RGB = [52, 158, 74];
const LEAF_DEEP: RGB = [33, 120, 56];
const PETAL: RGB = [255, 92, 128];
const PETAL_SOFT: RGB = [255, 160, 186];
const HEART: RGB = [255, 214, 92];
const POT: RGB = [205, 112, 74];
const POT_RIM: RGB = [222, 132, 92];

// Пружинный ход между ключами: каждый ключ ведёт значение к новой цели.
export const track = (keys: PlantKey[], field: 'health' | 'bloom', t: number, fps: number, duration: number, bounce: number) => {
  let v = 0;
  let from = 0;
  for (const k of keys) {
    const target = k[field];
    if (target === undefined) continue;
    if (t < k.at) break;
    from = v;
    const p = sui((t - k.at) * fps, fps, duration, bounce);
    v = from + (target - from) * p;
  }
  return v;
};

// Стебли: угол от вертикали, длина, сколько листьев, цветёт ли.
const STEMS = [
  {a: -58, len: 250, flower: false, side: -1},
  {a: -36, len: 330, flower: true, side: -1},
  {a: -14, len: 400, flower: true, side: 1},
  {a: 4, len: 360, flower: false, side: -1},
  {a: 20, len: 410, flower: true, side: 1},
  {a: 40, len: 320, flower: true, side: 1},
  {a: 62, len: 240, flower: false, side: 1},
];

const leafPath = (len: number) => {
  // Лист-сердечко: от черешка вперёд по оси x.
  const w = len * 0.55;
  return `M0 0 C ${len * 0.25} ${-w * 0.9} ${len * 0.95} ${-w * 0.55} ${len} 0 C ${len * 0.95} ${w * 0.55} ${len * 0.25} ${w * 0.9} 0 0 Z`;
};

export const Plant: React.FC<{
  x: number;
  y: number; // низ горшка
  h: number; // высота всей картинки
  health: number;
  bloom: number;
  t: number;
  dark?: boolean;
}> = ({x, y, h, health, bloom, t, dark}) => {
  const k = h / 640; // единицы рисунка
  const leafCol = mix(DRY_LEAF, LEAF, health);
  const leafDeep = mix(mix(DRY_LEAF, [0, 0, 0], 0.15), LEAF_DEEP, health);
  const baseX = 200;
  const baseY = 470;

  const stems = STEMS.map((st, i) => {
    const sway = Math.sin(t * 1.3 + i * 1.7) * 2.2 * health;
    // Поникший стебель уходит вбок и вниз, лист опускается.
    const droop = (1 - health) * (st.a >= 0 ? 1 : -1) * (48 + Math.abs(st.a) * 0.5);
    const ang = ((st.a + droop + sway) * Math.PI) / 180;
    const len = st.len * (0.82 + 0.18 * health);
    const bend = (1 - health) * 0.55 + 0.12;
    const tipX = baseX + Math.sin(ang) * len;
    const tipY = baseY - Math.cos(ang) * len * (1 - (1 - health) * 0.35);
    const ctrlX = baseX + Math.sin(ang) * len * 0.35 * (1 - bend);
    const ctrlY = baseY - Math.cos(ang) * len * 0.75;
    // Ориентация конца стебля.
    const dx = tipX - ctrlX;
    const dy = tipY - ctrlY;
    const tipDeg = (Math.atan2(dy, dx) * 180) / Math.PI;
    const leafLen = (st.flower ? 92 : 120) * (0.85 + 0.15 * health);
    const midT = 0.55;
    const mx = (1 - midT) * (1 - midT) * baseX + 2 * (1 - midT) * midT * ctrlX + midT * midT * tipX;
    const my = (1 - midT) * (1 - midT) * baseY + 2 * (1 - midT) * midT * ctrlY + midT * midT * tipY;
    const midDeg = tipDeg + st.side * (55 - 25 * (1 - health)) + (1 - health) * 35 * st.side;

    const flowers = st.flower
      ? [0, 1, 2].map((j) => {
          const local = Math.max(0, Math.min(1, bloom * 4 - (i * 0.35 + j * 0.25)));
          const sc = local <= 0 ? 0 : sui(local * 30, 30, 0.6, 0.32) * (j === 0 ? 1.25 : 0.95);
          if (sc <= 0.01) return null;
          const off = [
            [0, 0],
            [-26, 18],
            [24, 22],
          ][j];
          const rot = t * 8 * (j % 2 ? 1 : -1) + i * 20;
          const col = j === 0 ? PETAL : PETAL_SOFT;
          return (
            <g key={j} transform={`translate(${tipX + off[0]} ${tipY - 18 + off[1]}) rotate(${rot}) scale(${sc * 1.75})`}>
              {flowerCircles().map((c, n) => (
                <circle key={n} cx={c.x} cy={c.y} r={c.r} fill={rgb(col)} />
              ))}
              <circle r={5.2} fill={rgb(HEART)} />
            </g>
          );
        })
      : null;

    return (
      <g key={i}>
        <path
          d={`M${baseX} ${baseY} Q ${ctrlX} ${ctrlY} ${tipX} ${tipY}`}
          stroke={rgb(leafDeep)}
          strokeWidth={7}
          fill="none"
          strokeLinecap="round"
        />
        <g transform={`translate(${mx} ${my}) rotate(${midDeg})`}>
          <path d={leafPath(leafLen * 0.8)} fill={rgb(leafDeep)} />
          <path d={`M4 0 L ${leafLen * 0.72} 0`} stroke={rgb(mix(leafDeep, [255, 255, 255], 0.25))} strokeWidth={2.5} />
        </g>
        {!st.flower && (
          <g transform={`translate(${tipX} ${tipY}) rotate(${tipDeg})`}>
            <path d={leafPath(leafLen)} fill={rgb(leafCol)} />
            <path d={`M4 0 L ${leafLen * 0.9} 0`} stroke={rgb(mix(leafCol, [255, 255, 255], 0.3))} strokeWidth={3} />
          </g>
        )}
        {st.flower && (
          <g transform={`translate(${tipX} ${tipY}) rotate(${tipDeg + 70 * st.side})`}>
            <path d={leafPath(leafLen * 0.75)} fill={rgb(leafCol)} />
          </g>
        )}
        {flowers}
      </g>
    );
  });

  return (
    <svg
      width={400 * k}
      height={640 * k}
      viewBox="0 0 400 640"
      style={{position: 'absolute', left: x - 200 * k, top: y - 640 * k, overflow: 'visible'}}
    >
      <ellipse cx={200} cy={634} rx={120} ry={10} fill={dark ? 'rgba(0,0,0,0.35)' : 'rgba(30,60,30,0.12)'} />
      {stems}
      {/* Горшок */}
      <path d="M118 488 L282 488 L262 630 Q260 638 252 638 L148 638 Q140 638 138 630 Z" fill={rgb(POT)} />
      <rect x={104} y={462} width={192} height={38} rx={10} fill={rgb(POT_RIM)} />
      <ellipse cx={200} cy={466} rx={86} ry={9} fill={rgb([96, 64, 44])} />
    </svg>
  );
};
