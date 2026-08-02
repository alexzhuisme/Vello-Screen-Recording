'use strict';

import path from 'path';
import {BrowserWindow, ipcMain} from 'electron';
import pEvent from 'p-event';

import {sendToRenderer} from '../ipc-handlers';
import {loadRoute} from '../utils/routes';
import {windowManager} from './manager';

const openConfigWindow = async (pluginName: string) => {
  const prefsWindow = await windowManager.preferences?.open();
  const configWindow = new BrowserWindow({
    width: 320,
    height: 436,
    resizable: false,
    movable: false,
    minimizable: false,
    maximizable: false,
    fullscreenable: false,
    titleBarStyle: 'hiddenInset',
    show: false,
    parent: prefsWindow,
    modal: true,
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      preload: path.join(__dirname, '..', 'preload.js')
    }
  });

  loadRoute(configWindow, 'config');

  configWindow.webContents.on('did-finish-load', () => {
    sendToRenderer(configWindow, 'plugin', pluginName);
    configWindow.show();
  });

  await pEvent(configWindow, 'closed');
};

const openEditorConfigWindow = async (pluginName: string, serviceTitle: string, editorWindow: BrowserWindow) => {
  const configWindow = new BrowserWindow({
    width: 480,
    height: 420,
    resizable: false,
    movable: false,
    minimizable: false,
    maximizable: false,
    fullscreenable: false,
    titleBarStyle: 'hiddenInset',
    show: false,
    parent: editorWindow,
    modal: true,
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      preload: path.join(__dirname, '..', 'preload.js')
    }
  });

  loadRoute(configWindow, 'config');

  configWindow.webContents.on('did-finish-load', () => {
    sendToRenderer(configWindow, 'edit-service', {pluginName, serviceTitle});
    configWindow.show();
  });

  await pEvent(configWindow, 'closed');
};

ipcMain.handle('open-edit-config', async (event, {pluginName, serviceTitle}) => {
  const editorWindow = BrowserWindow.fromWebContents(event.sender);
  if (editorWindow) {
    return openEditorConfigWindow(pluginName, serviceTitle, editorWindow);
  }
});

windowManager.setConfig({
  open: openConfigWindow
});
