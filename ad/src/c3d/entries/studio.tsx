import React from 'react';
import {Composition, registerRoot} from 'remotion';
import {StudioPreview} from '../Studio';
import {DURATION_FRAMES, FPS, H, W} from '../shared';

registerRoot(() => (
  <Composition id="StudioPreview" component={StudioPreview} durationInFrames={DURATION_FRAMES} fps={FPS} width={W} height={H} />
));
