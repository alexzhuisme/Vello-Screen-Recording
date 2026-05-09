'use strict';

import {Tray, Menu} from 'electron';
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
  animateIcon();

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

const animateIcon = async () => new Promise<void>(resolve => {
  const interval = 20;
  let i = 0;

  const next = () => {
    trayAnimation = setTimeout(() => {
      const number = String(i++).padStart(5, '0');
      const filename = `loading_${number}Template.png`;

      try {
        tray.setImage(path.join(__dirname, '..', 'static', 'menubar-loading', filename));
        next();
      } catch {
        trayAnimation = undefined;
        resolve();
      }
    }, interval);
  };

  next();
});
