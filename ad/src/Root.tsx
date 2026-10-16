import React from 'react';
import {Composition} from 'remotion';
import {Film, Scene, starts} from './Film';
import {scenesB, scenesC} from './concepts';

const FPS = 30;

// Все форматы: основной 9:16, нарезка 15 с, 1:1 и 16:9.
const formats = [
  {id: '9x16', w: 1080, h: 1920, cut: 'full' as const},
  {id: '9x16-15s', w: 1080, h: 1920, cut: 'short' as const},
  {id: '1x1', w: 1080, h: 1080, cut: 'full' as const},
  {id: '16x9', w: 1920, h: 1080, cut: 'full' as const},
];

const B: React.FC<{cut: 'full' | 'short'}> = ({cut}) => <Film scenes={scenesB(cut)} />;
const Cc: React.FC<{cut: 'full' | 'short'}> = ({cut}) => <Film scenes={scenesC(cut)} dark />;

const frames = (scenes: Scene[]) => Math.round(starts(scenes).total * FPS);

export const Root: React.FC = () => (
  <>
    {formats.map((f) => (
      <Composition
        key={`B-${f.id}`}
        id={`B-${f.id}`}
        component={B}
        durationInFrames={frames(scenesB(f.cut))}
        fps={FPS}
        width={f.w}
        height={f.h}
        defaultProps={{cut: f.cut}}
      />
    ))}
    {formats.map((f) => (
      <Composition
        key={`C-${f.id}`}
        id={`C-${f.id}`}
        component={Cc}
        durationInFrames={frames(scenesC(f.cut))}
        fps={FPS}
        width={f.w}
        height={f.h}
        defaultProps={{cut: f.cut}}
      />
    ))}
  </>
);
