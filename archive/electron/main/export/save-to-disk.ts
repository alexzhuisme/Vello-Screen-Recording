'use strict';

import {BrowserWindow, dialog, app, Notification, shell} from 'electron';
import {ShareServiceContext} from '../plugins/service-context';
import {settings} from '../common/settings';
import makeDir from 'make-dir';
import {Format} from '../common/types';
import path from 'path';
import cpFile from 'cp-file';
import {ShareService} from '../plugins/service';

const extensionByFormat: Record<Format, string> = {
  [Format.gif]: 'gif',
  [Format.webm]: 'webm',
  [Format.apng]: 'apng',
  [Format.mp4]: 'mp4',
  [Format.av1]: 'mp4',
  [Format.hevc]: 'mp4'
};

let customSaveDir: string | undefined;

export const getSaveDir = (): string => customSaveDir ?? app.getPath('downloads');

export const setSaveDir = (dir: string): void => {
  customSaveDir = dir;
};

export const getSavePath = (format: Format, fileName: string): string => {
  const baseName = path.parse(fileName).name;
  const ext = extensionByFormat[format] ?? 'mp4';
  return path.join(getSaveDir(), `${baseName}.${ext}`);
};

const filterMap = new Map([
  [Format.mp4, [{name: 'Movies', extensions: ['mp4']}]],
  [Format.webm, [{name: 'Movies', extensions: ['webm']}]],
  [Format.gif, [{name: 'Images', extensions: ['gif']}]],
  [Format.apng, [{name: 'Images', extensions: ['apng']}]],
  [Format.av1, [{name: 'Movies', extensions: ['mp4']}]],
  [Format.hevc, [{name: 'Movies', extensions: ['mp4']}]]
]);

let lastSavedDirectory: string;

export const askForTargetFilePath = async (
  window: BrowserWindow,
  format: Format,
  fileName: string
) => {
  const kapturesDir = settings.get('kapturesDir');
  await makeDir(kapturesDir);

  const defaultPath = path.join(lastSavedDirectory ?? kapturesDir, fileName);

  const filters = filterMap.get(format);

  const {filePath} = await dialog.showSaveDialog(window, {
    title: fileName,
    defaultPath,
    filters
  });

  if (filePath) {
    lastSavedDirectory = path.dirname(filePath);
    return filePath;
  }

  return undefined;
};

const action = async (context: ShareServiceContext) => {
  const targetFilePath = (context as ShareServiceContext & {targetFilePath: string}).targetFilePath;
  const temporaryFilePath = await context.filePath();

  if (context.isCanceled) {
    return;
  }

  await cpFile(temporaryFilePath, targetFilePath);

  const notification = new Notification({
    title: 'File saved successfully!',
    body: 'Click to show the file in Finder'
  });

  notification.on('click', () => {
    shell.showItemInFolder(targetFilePath);
  });

  notification.show();
};

export const saveToDiskShareService: ShareService = {
  title: 'Save to Disk',
  formats: [
    Format.gif,
    Format.mp4,
    Format.webm,
    Format.apng,
    Format.av1,
    Format.hevc
  ],
  action
};
