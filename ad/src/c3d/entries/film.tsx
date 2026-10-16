import React from 'react';
import {Composition, registerRoot} from 'remotion';
import {Film3D} from '../Film3D';
import {DURATION_FRAMES, FPS, H, W} from '../shared';

registerRoot(() => (
  <Composition id="C3D-9x16" component={Film3D} durationInFrames={DURATION_FRAMES} fps={FPS} width={W} height={H} />
));
