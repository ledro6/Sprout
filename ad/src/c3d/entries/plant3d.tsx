import React from 'react';
import {Composition, registerRoot} from 'remotion';
import {Plant3DPreview} from '../Plant3D';
import {DURATION_FRAMES, FPS, H, W} from '../shared';

registerRoot(() => (
  <Composition id="Plant3DPreview" component={Plant3DPreview} durationInFrames={DURATION_FRAMES} fps={FPS} width={W} height={H} />
));
