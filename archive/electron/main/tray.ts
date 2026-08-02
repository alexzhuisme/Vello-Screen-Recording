'use strict';

import {Tray, Menu, nativeImage, NativeImage} from 'electron';
import {KeyboardEvent} from 'electron/main';
import path from 'path';
import {getCogMenuTemplate} from './menus/cog';
import {getRecordMenu} from './menus/record';
import {track} from './common/analytics';
import {openFiles} from './utils/open-files';
import {windowManager} from './windows/manager';
import {pauseRecording, resumeRecording, stopRecording} from './aperture';
import {MenuOptions} from './menus/utils';

/**
 * Stable UUID for `new Tray(image, guid)`. macOS (and Windows with signing) use this to
 * persist menu-bar/tray placement across launches after the user drags the icon — apps
 * cannot programmatically pin next to the system Wi‑Fi/battery cluster.
 */
export const TRAY_GUID = 'c4f7e2b9-8a3d-41ac-9f51-6dbe8c7a2f30';

let tray: Tray;
let trayAnimation: NodeJS.Timeout | undefined;
let rendererReady = false;

export const setRendererReady = () => {
  rendererReady = true;
};

const getTrayMenu = async () => {
  const cogItems = await getCogMenuTemplate();

  const template: MenuOptions = [
    {
      label: 'New Recording',
      enabled: rendererReady,
      click: () => {
        windowManager.cropper?.open();
      }
    },
    {type: 'separator'},
    ...cogItems
  ];

  return Menu.buildFromTemplate(template);
};

const openTrayMenu = async () => {
  tray.popUpContextMenu(await getTrayMenu());
};

const openRecordingContextMenu = async () => {
  tray.popUpContextMenu(await getRecordMenu(false));
};

const openPausedContextMenu = async () => {
  tray.popUpContextMenu(await getRecordMenu(true));
};

export const initializeTray = () => {
  tray = new Tray(path.join(__dirname, '..', 'static', 'menubarDefaultTemplate.png'), TRAY_GUID);
  tray.on('click', openTrayMenu);
  tray.on('right-click', openTrayMenu);
  tray.on('drop-files', (_, files) => {
    track('editor/opened/tray');
    openFiles(...files);
  });

  return tray;
};

export const disableTray = () => {
  tray.removeListener('click', openTrayMenu);
  tray.removeListener('right-click', openTrayMenu);
};

export const resetTray = () => {
  if (trayAnimation) {
    clearTimeout(trayAnimation);
  }

  tray.removeAllListeners('click');
  tray.removeAllListeners('right-click');

  tray.setImage(path.join(__dirname, '..', 'static', 'menubarDefaultTemplate.png'));
  tray.on('click', openTrayMenu);
  tray.on('right-click', openTrayMenu);
};

export const setRecordingTray = () => {
  animateRecordingIcon();

  tray.removeAllListeners('right-click');

  // TODO: figure out why this is marked as missing. It's defined properly in the electron.d.ts file
  tray.once('click', onRecordingTrayClick);
  tray.on('right-click', openRecordingContextMenu);
};

export const setPausedTray = () => {
  if (trayAnimation) {
    clearTimeout(trayAnimation);
  }

  tray.removeAllListeners('right-click');

  tray.setImage(path.join(__dirname, '..', 'static', 'pauseTemplate.png'));
  tray.once('click', resumeRecording);
  tray.on('right-click', openPausedContextMenu);
};

const onRecordingTrayClick = (event: KeyboardEvent) => {
  if (event.altKey) {
    pauseRecording();
    return;
  }

  stopRecording();
};

// Red breathing animation built from the default tray icon. We tint every
// non-transparent pixel red and modulate the alpha channel through a smooth
// cosine curve to get a calm "breathing" pulse while recording.
const RECORDING_FRAME_COUNT = 32;
const RECORDING_FRAME_INTERVAL_MS = 60;
let recordingFrames: NativeImage[] | undefined;

// Electron's `toBitmap()` returns BGRA on Windows/macOS/Linux.
const tintRedBgra = (bitmap: Buffer, alphaScale: number): Buffer => {
  const out = Buffer.from(bitmap);
  for (let i = 0; i < out.length; i += 4) {
    const alpha = out[i + 3];
    if (alpha === 0) {
      continue;
    }

    out[i] = 0; // B
    out[i + 1] = 0; // G
    out[i + 2] = 255; // R
    out[i + 3] = Math.min(255, Math.round(alpha * alphaScale));
  }

  return out;
};

const buildRecordingFrames = (): NativeImage[] => {
  if (recordingFrames) {
    return recordingFrames;
  }

  const base1x = nativeImage.createFromPath(path.join(__dirname, '..', 'static', 'menubarDefaultTemplate.png'));
  const base2x = nativeImage.createFromPath(path.join(__dirname, '..', 'static', 'menubarDefaultTemplate@2x.png'));

  const size1x = base1x.getSize();
  const size2x = base2x.getSize();
  const bitmap1x = base1x.toBitmap();
  const bitmap2x = base2x.toBitmap();

  const frames: NativeImage[] = [];
  for (let i = 0; i < RECORDING_FRAME_COUNT; i++) {
    const t = i / RECORDING_FRAME_COUNT;
    const eased = (1 - Math.cos(2 * Math.PI * t)) / 2; // 0 → 1 → 0
    const alphaScale = 0.35 + (0.65 * eased);

    const tinted1x = tintRedBgra(bitmap1x, alphaScale);
    const tinted2x = tintRedBgra(bitmap2x, alphaScale);

    const image = nativeImage.createFromBitmap(tinted1x, {
      width: size1x.width,
      height: size1x.height,
      scaleFactor: 1
    });

    if (size2x.width > 0 && size2x.height > 0) {
      image.addRepresentation({
        scaleFactor: 2,
        width: size2x.width,
        height: size2x.height,
        buffer: tinted2x
      });
    }

    image.setTemplateImage(false);
    frames.push(image);
  }

  recordingFrames = frames;
  return frames;
};

const animateRecordingIcon = () => {
  const frames = buildRecordingFrames();
  if (frames.length === 0) {
    return;
  }

  let i = 0;
  const tick = () => {
    trayAnimation = setTimeout(() => {
      try {
        tray.setImage(frames[i % frames.length]);
        i += 1;
        tick();
      } catch {
        trayAnimation = undefined;
      }
    }, RECORDING_FRAME_INTERVAL_MS);
  };

  tick();
};
