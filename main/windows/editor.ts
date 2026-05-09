import {EditorWindowState} from '../common/types';
import type {Video} from '../video';
import KapWindow from './kap-window';
import {MenuItemId} from '../menus/utils';
import {BrowserWindow, dialog, app} from 'electron';
import fs from 'fs';
import {windowManager} from './manager';
import {exitFullScreenIfNeeded} from '../utils/fullscreen';

const pify = require('pify');

const OPTIONS_BAR_HEIGHT = 48;
const VIDEO_ASPECT = 9 / 16;
const MIN_VIDEO_WIDTH = 900;
const MIN_VIDEO_HEIGHT = MIN_VIDEO_WIDTH * VIDEO_ASPECT;
const MIN_WINDOW_HEIGHT = MIN_VIDEO_HEIGHT + OPTIONS_BAR_HEIGHT;

const editors = new Map();
const editorsWithNotSavedDialogs = new Map();

const open = async (video: Video) => {
  if (editors.has(video.filePath)) {
    editors.get(video.filePath).show();
    return;
  }

  // Open quickly after lightweight metadata is available; preview transcoding can
  // continue in the background and update the renderer once ready.
  await video.whenReady();

  const editorKapWindow = new KapWindow<EditorWindowState>({
    title: video.title,
    waitForMount: false,
    // TODO: Return those to the original values when we are able to resize below min size
    // Upstream issue: https://github.com/electron/electron/issues/27025
    // minWidth: MIN_VIDEO_WIDTH,
    // minHeight: MIN_WINDOW_HEIGHT,
    minWidth: 360,
    minHeight: 392,
    width: MIN_VIDEO_WIDTH,
    height: MIN_WINDOW_HEIGHT,
    backgroundColor: '#222222',
    webPreferences: {
      webSecurity: app.isPackaged
    },
    frame: false,
    transparent: true,
    vibrancy: 'window',
    route: 'editor',
    initialState: {
      previewFilePath: video.previewPath,
      filePath: video.filePath,
      fps: video.fps ?? 30,
      title: video.title
    },
    menu: defaultMenu => {
      if (!video.isNewRecording) {
        return;
      }

      const fileMenu = defaultMenu.find(item => item.id === MenuItemId.file);

      if (fileMenu) {
        const submenu = fileMenu.submenu as Electron.MenuItemConstructorOptions[];

        submenu.splice(0, 0, {
          label: 'Save Original…',
          id: MenuItemId.saveOriginal,
          accelerator: 'Command+S',
          click: async () => saveOriginal(video)
        }, {
          type: 'separator'
        });
      }
    }
  });

  const editorWindow = editorKapWindow.browserWindow;

  editors.set(video.filePath, editorWindow);

  void video.whenPreviewReady().then(previewFilePath => {
    if (!previewFilePath || editorWindow.isDestroyed()) {
      return;
    }

    const previousState = editorKapWindow.state;
    if (!previousState) {
      return;
    }

    editorKapWindow.setState({
      ...previousState,
      previewFilePath
    });
  }).catch(() => {
    // Keep editor usable even if preview generation fails.
  });

  if (video.isNewRecording) {
    editorWindow.setDocumentEdited(true);
    let allowCloseWithoutConfirm = false;
    editorWindow.on('close', (event: Electron.Event) => {
      if (allowCloseWithoutConfirm) {
        return;
      }

      event.preventDefault();
      editorsWithNotSavedDialogs.set(video.filePath, true);

      void (async () => {
        try {
          await exitFullScreenIfNeeded(editorWindow);
          if (editorWindow.isDestroyed()) {
            return;
          }

          const {response} = await dialog.showMessageBox(editorWindow, {
            type: 'question',
            buttons: [
              'Discard',
              'Cancel'
            ],
            defaultId: 0,
            cancelId: 1,
            message: 'Are you sure that you want to discard this recording?',
            detail: 'You will no longer be able to edit and export the original recording.'
          });
          if (response === 0) {
            allowCloseWithoutConfirm = true;
            editorWindow.close();
          }
        } finally {
          editorsWithNotSavedDialogs.delete(video.filePath);
        }
      })();
    });
  }

  editorWindow.on('closed', () => {
    editors.delete(video.filePath);
  });

  editorWindow.on('blur', () => {
    editorKapWindow.sendToRenderer('blur');
  });

  editorWindow.on('focus', () => {
    editorKapWindow.sendToRenderer('focus');
  });
};

const saveOriginal = async (video: Video) => {
  const {filePath} = await dialog.showSaveDialog(BrowserWindow.getFocusedWindow()!, {
    defaultPath: `${video.title}.mp4`
  });

  if (filePath) {
    await pify(fs.copyFile)(video.filePath, filePath, fs.constants.COPYFILE_FICLONE);
  }
};

const areAnyBlocking = () => {
  if (editorsWithNotSavedDialogs.size > 0) {
    const [path] = editorsWithNotSavedDialogs.keys();
    editors.get(path).focus();
    return true;
  }

  return false;
};

windowManager.setEditor({
  open,
  areAnyBlocking
});
