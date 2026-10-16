import React from 'react';
import {Composition, registerRoot} from 'remotion';
import {OverlayPreview} from '../Overlay';
import {DURATION_FRAMES, FPS, H, W} from '../shared';

registerRoot(() => (
  <Composition id="OverlayPreview" component={OverlayPreview} durationInFrames={DURATION_FRAMES} fps={FPS} width={W} height={H} />
));
