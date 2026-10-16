// node render.mjs stills B-9x16 1.5 4 12      — кадры для проверки (секунды)
// node render.mjs video B-9x16 C-9x16 ...      — MP4 в out/
// node render.mjs all                          — все композиции
import {bundle} from '@remotion/bundler';
import {renderMedia, renderStill, selectComposition, getCompositions} from '@remotion/renderer';
import path from 'node:path';
import fs from 'node:fs';

const chromiumOptions = {gl: process.env.GL ?? 'angle'};
const browserExecutable = '/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell';
const [mode, ...args] = process.argv.slice(2);
const serveUrl = await bundle({entryPoint: path.resolve(process.env.ENTRY ?? 'src/index.ts'), publicDir: path.resolve('public')});
const outDir = process.env.OUTDIR ?? 'out/stills';
fs.mkdirSync(outDir, {recursive: true});

if (mode === 'stills') {
  const [id, ...times] = args;
  const composition = await selectComposition({serveUrl, id, browserExecutable, chromiumOptions});
  for (const s of times) {
    const frame = Math.min(Math.round(Number(s) * composition.fps), composition.durationInFrames - 1);
    const output = `${outDir}/${id}-${s}.jpg`;
    await renderStill({composition, serveUrl, output, frame, browserExecutable, chromiumOptions, timeoutInMilliseconds: 180000, imageFormat: 'jpeg', jpegQuality: 85});
    console.log(output);
  }
} else {
  const ids = mode === 'all' ? (await getCompositions(serveUrl, {browserExecutable})).map((c) => c.id) : args;
  for (const id of ids) {
    const composition = await selectComposition({serveUrl, id, browserExecutable, chromiumOptions});
    const outputLocation = `out/Sprout-${id}.mp4`;
    const t0 = Date.now();
    await renderMedia({
      composition,
      serveUrl,
      codec: 'h264',
      crf: 18,
      browserExecutable,
      chromiumOptions,
      timeoutInMilliseconds: 180000,
      frameRange: process.env.FRAMES ? process.env.FRAMES.split('-').map(Number) : undefined,
      outputLocation: process.env.OUTFILE ?? outputLocation,
      onProgress: ({renderedFrames}) => { if (renderedFrames % 30 === 0) console.log('frames', renderedFrames, ((Date.now() - t0) / 1000).toFixed(0) + 's'); },
      concurrency: Number(process.env.CONC ?? 4),
      imageFormat: 'jpeg',
      jpegQuality: 92,
    });
    console.log(outputLocation, ((Date.now() - t0) / 1000).toFixed(0) + 's');
  }
}
