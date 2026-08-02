import {ipcMain, BrowserWindow, systemPreferences, dialog, shell, Menu, nativeImage, nativeTheme, app, MenuItemConstructorOptions} from 'electron';
import {settings} from './common/settings';
import {track} from './common/analytics';
import {showError} from './utils/errors';
import {getAudioDevices, getDefaultInputDevice, getSelectedInputDeviceId} from './utils/devices';
import {startRecording, stopRecording, pauseRecording, resumeRecording} from './aperture';
import {closeBrowserWindowSafely, exitFullScreenIfNeeded} from './utils/fullscreen';

const getWindowFromEvent = (event: Electron.IpcMainInvokeEvent): BrowserWindow | null =>
  BrowserWindow.fromWebContents(event.sender);

const buildMenuWithIds = (
  template: any[],
  onItemClicked: (value: any) => void
): MenuItemConstructorOptions[] =>
  template.map((item: any) => {
    if (item.type === 'separator' || item.separator) {
      return {type: 'separator' as const};
    }

    const menuItem: MenuItemConstructorOptions = {
      label: item.label,
      type: item.type,
      checked: item.checked,
      enabled: item.enabled !== false,
      visible: item.visible !== false
    };

    if (item.iconDataUrl) {
      menuItem.icon = nativeImage.createFromDataURL(item.iconDataUrl).resize({width: 16, height: 16});
    }

    if (item.submenu) {
      menuItem.submenu = buildMenuWithIds(item.submenu, onItemClicked);
    } else if (item.value !== undefined || item.click) {
      menuItem.click = () => onItemClicked(item.value ?? item.label);
    }

    return menuItem;
  });

let requestCounter = 0;

export async function callRenderer<R = void>(window: BrowserWindow, channel: string, data?: any): Promise<R> {
  const requestId = ++requestCounter;
  return new Promise<R>(resolve => {
    ipcMain.once(`kap:reply:${channel}:${requestId}`, (_, result) => {
      resolve(result as R);
    });
    window.webContents.send(channel, data, requestId);
  });
}

export function sendToRenderer(window: BrowserWindow, channel: string, data?: any): void {
  if (!window.isDestroyed()) {
    window.webContents.send(channel, data);
  }
}

export const registerIpcHandlers = () => {
  // --- Window operations ---
  ipcMain.handle('kap:window:close', event => {
    closeBrowserWindowSafely(getWindowFromEvent(event));
  });

  ipcMain.handle('kap:window:exitFullScreenIfNeeded', async event =>
    exitFullScreenIfNeeded(getWindowFromEvent(event)));
  ipcMain.handle('kap:window:minimize', event => getWindowFromEvent(event)?.minimize());
  ipcMain.handle('kap:window:maximize', event => getWindowFromEvent(event)?.maximize());
  ipcMain.handle('kap:window:show', event => getWindowFromEvent(event)?.show());
  ipcMain.handle('kap:window:focus', event => getWindowFromEvent(event)?.focus());

  ipcMain.handle('kap:window:getBounds', event => getWindowFromEvent(event)?.getBounds());

  ipcMain.handle('kap:window:setBounds', (event, bounds, animate) => {
    getWindowFromEvent(event)?.setBounds(bounds, animate);
  });

  ipcMain.handle('kap:window:getSize', event => getWindowFromEvent(event)?.getSize());

  ipcMain.handle('kap:window:setSize', (event, width, height) => {
    getWindowFromEvent(event)?.setSize(width, height);
  });

  ipcMain.handle('kap:window:setContentSize', (event, width, height) => {
    getWindowFromEvent(event)?.setContentSize(width, height);
  });

  ipcMain.handle('kap:window:getContentSize', event => getWindowFromEvent(event)?.getContentSize());

  ipcMain.handle('kap:window:setResizable', (event, resizable) => {
    getWindowFromEvent(event)?.setResizable(resizable);
  });

  ipcMain.handle('kap:window:setFullScreenable', (event, fullscreenable) => {
    getWindowFromEvent(event)?.setFullScreenable(fullscreenable);
  });

  ipcMain.handle('kap:window:setIgnoreMouseEvents', (event, ignore, options) => {
    getWindowFromEvent(event)?.setIgnoreMouseEvents(ignore, options);
  });

  ipcMain.handle('kap:window:isVisible', event => getWindowFromEvent(event)?.isVisible());

  // --- System ---
  ipcMain.handle('kap:system:getAccentColor', () => systemPreferences.getAccentColor());

  ipcMain.handle('kap:system:getColor', (_, name) =>
    systemPreferences.getColor(name));

  ipcMain.handle('kap:system:getUserDefault', (_, key, type) =>
    systemPreferences.getUserDefault(key, type));

  ipcMain.handle('kap:system:isDarkMode', () => nativeTheme.shouldUseDarkColors);

  const notificationSubscriptions = new Map<number, number>();
  let notificationCounter = 0;

  ipcMain.handle('kap:system:subscribeNotification', (event, name) => {
    const id = ++notificationCounter;
    const nativeId = systemPreferences.subscribeNotification(name, () => {
      const win = getWindowFromEvent(event);
      if (win && !win.isDestroyed()) {
        win.webContents.send(`kap:system:notification:${id}`);
      }
    });
    notificationSubscriptions.set(id, nativeId);
    return id;
  });

  ipcMain.handle('kap:system:unsubscribeNotification', (_, id) => {
    const nativeId = notificationSubscriptions.get(id);
    if (nativeId !== undefined) {
      systemPreferences.unsubscribeNotification(nativeId);
      notificationSubscriptions.delete(id);
    }
  });

  nativeTheme.on('updated', () => {
    for (const win of BrowserWindow.getAllWindows()) {
      if (!win.isDestroyed()) {
        win.webContents.send('kap:system:theme-changed', nativeTheme.shouldUseDarkColors);
      }
    }
  });

  systemPreferences.on('accent-color-changed' as any, (_: any, color: string) => {
    for (const win of BrowserWindow.getAllWindows()) {
      if (!win.isDestroyed()) {
        win.webContents.send('kap:system:accent-color-changed', color);
      }
    }
  });

  // --- Dialog ---
  ipcMain.handle('kap:dialog:showMessageBox', async (event, options) => {
    const win = getWindowFromEvent(event);
    return win ?
      dialog.showMessageBox(win, options) :
      dialog.showMessageBox(options);
  });

  ipcMain.on('kap:dialog:showMessageBoxSync', (event, options) => {
    const win = getWindowFromEvent(event);
    event.returnValue = win ?
      dialog.showMessageBoxSync(win, options) :
      dialog.showMessageBoxSync(options);
  });

  ipcMain.handle('kap:dialog:showOpenDialog', async (event, options) => {
    const win = getWindowFromEvent(event);
    return win ?
      dialog.showOpenDialog(win, options) :
      dialog.showOpenDialog(options);
  });

  ipcMain.handle('kap:dialog:showSaveDialog', async (event, options) => {
    const win = getWindowFromEvent(event);
    return win ?
      dialog.showSaveDialog(win, options) :
      dialog.showSaveDialog(options);
  });

  // --- Shell ---
  ipcMain.handle('kap:shell:openExternal', async (_, url) => shell.openExternal(url));
  ipcMain.handle('kap:shell:openPath', async (_, path) => shell.openPath(path));
  ipcMain.handle('kap:shell:showItemInFolder', async (_, path) => {
    shell.showItemInFolder(path);
  });

  // --- Menu ---
  ipcMain.handle('kap:menu:popup', (event, template, position) => {
    const win = getWindowFromEvent(event);
    if (!win) {
      return null;
    }

    return new Promise<any>(resolve => {
      let resolved = false;
      const menuTemplate = buildMenuWithIds(template, value => {
        if (!resolved) {
          resolved = true;
          resolve(value);
        }
      });

      const menu = Menu.buildFromTemplate(menuTemplate);
      menu.popup({
        window: win,
        x: position?.x,
        y: position?.y,
        callback: () => {
          if (!resolved) {
            resolved = true;
            resolve(null);
          }
        }
      });
    });
  });

  // --- App ---
  ipcMain.handle('kap:app:getVersion', () => app.getVersion());
  ipcMain.handle('kap:app:getName', () => app.getName());
  ipcMain.handle('kap:app:getPath', (_, name) => app.getPath(name));
  ipcMain.handle('kap:app:getLoginItemSettings', () => app.getLoginItemSettings());
  ipcMain.handle('kap:app:setLoginItemSettings', (_, loginSettings) => {
    app.setLoginItemSettings(loginSettings);
  });
  ipcMain.handle('kap:app:quit', () => app.quit());
  ipcMain.handle('kap:app:isDevelopment', () => !app.isPackaged);

  // --- Settings ---
  ipcMain.handle('settings:get', (_, key, defaultValue) => settings.get(key, defaultValue));
  ipcMain.handle('settings:set', (_, key, value) => settings.set(key, value));
  ipcMain.handle('settings:delete', (_, key) => settings.delete(key));
  ipcMain.handle('settings:getAll', () => settings.store);
  ipcMain.handle('settings:has', (_, key) => settings.has(key));

  ipcMain.handle('settings:getShortcuts', () => {
    const {shortcuts} = require('./common/settings');
    return shortcuts;
  });

  const {flags} = require('./common/flags');
  ipcMain.handle('flags:get', async (_, key: string) => flags.get(key));
  ipcMain.handle('flags:set', async (_, key: string, value: unknown) => flags.set(key, value));

  // --- Devices ---
  ipcMain.handle('devices:getAudioDevices', async () => getAudioDevices());
  ipcMain.handle('devices:getDefaultInputDevice', async () => getDefaultInputDevice());
  ipcMain.handle('devices:getSelectedInputDeviceId', async () => getSelectedInputDeviceId());

  // --- System Permissions ---
  ipcMain.handle('system:ensureMicrophonePermissions', async () => {
    const {ensureMicrophonePermissions} = require('./common/system-permissions');
    return ensureMicrophonePermissions();
  });

  // --- Save directory ---
  ipcMain.handle('save:getDir', () => {
    const {getSaveDir} = require('./export/save-to-disk');
    return getSaveDir();
  });

  ipcMain.handle('save:chooseDir', async event => {
    const {getSaveDir, setSaveDir} = require('./export/save-to-disk');
    const win = getWindowFromEvent(event);
    const result = await dialog.showOpenDialog(win!, {
      defaultPath: getSaveDir(),
      properties: ['openDirectory', 'createDirectory']
    });

    if (!result.canceled && result.filePaths.length > 0) {
      setSaveDir(result.filePaths[0]);
      return result.filePaths[0];
    }

    return getSaveDir();
  });

  // --- Analytics ---
  ipcMain.handle('analytics:track', async (_, event) => track(event));

  // --- Errors ---
  ipcMain.handle('errors:show', async (_, error) => showError(error));

  // --- macOS Version ---
  ipcMain.handle('system:macosVersion:isGreaterThanOrEqualTo', (_, version) => {
    try {
      const macosVersion = require('macos-version');
      return macosVersion.isGreaterThanOrEqualTo(version);
    } catch {
      return false;
    }
  });

  // --- Aperture (recording) ---
  ipcMain.handle('aperture:startRecording', async (_, options) => startRecording(options));
  ipcMain.handle('aperture:stopRecording', async () => stopRecording());
  ipcMain.handle('aperture:pauseRecording', async () => pauseRecording());
  ipcMain.handle('aperture:resumeRecording', async () => resumeRecording());

  // --- Windows list ---
  ipcMain.handle('windows:getList', async () => {
    const {getWindowList} = require('./utils/windows');
    const list = await getWindowList();
    return list.map((win: any) => {
      const {icon, icon2x, ...rest} = win;
      return rest;
    });
  });

  ipcMain.handle('windows:activateWindow', async (_, ownerName) => {
    const {activateWindow} = require('mac-windows');
    return activateWindow(ownerName);
  });

  // --- Snapshots ---
  ipcMain.handle('save-snapshot', async (event, time: number) => {
    const win = getWindowFromEvent(event);
    if (!win) {
      return;
    }

    const KapWindowClass = require('./windows/kap-window').default;
    const kapWindow = KapWindowClass.fromId(win.id);
    const filePath = kapWindow?.state?.filePath;
    if (filePath) {
      const {Video} = require('./video');
      const {saveSnapshot} = require('./utils/image-preview');
      const video = Video.fromId(filePath);
      if (video) {
        saveSnapshot(video, time);
      }
    }
  });

  // --- Cog menu ---
  ipcMain.handle('cog:popupMenu', async event => {
    const {getCogMenuTemplate} = require('./menus/cog');
    const win = getWindowFromEvent(event);
    if (win) {
      const template = await getCogMenuTemplate();
      const menu = Menu.buildFromTemplate(template);
      menu.popup({window: win});
    }
  });

  // --- Usage refresh ---
  ipcMain.handle('refresh-usage', () => {
    // Triggers re-evaluation of plugin config state after editing
  });
};
