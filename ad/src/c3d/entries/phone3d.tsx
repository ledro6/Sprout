import React from 'react';
import {Composition, registerRoot} from 'remotion';
import {Phone3DPreview} from '../Phone3D';
import {DURATION_FRAMES, FPS, H, W} from '../shared';

registerRoot(() => (
  <Composition id="Phone3DPreview" component={Phone3DPreview} durationInFrames={DURATION_FRAMES} fps={FPS} width={W} height={H} />
));
