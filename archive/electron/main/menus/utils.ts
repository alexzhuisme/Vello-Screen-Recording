import {Menu} from 'electron';

export type MenuOptions = Parameters<typeof Menu.buildFromTemplate>[0];

export enum MenuItemId {
  sendFeedback = 'sendFeedback',
  about = 'about',
  preferences = 'preferences',
  file = 'file',
  edit = 'edit',
  window = 'window',
  help = 'help',
  app = 'app',
  saveOriginal = 'saveOriginal',
  plugins = 'plugins',
  audioDevices = 'audioDevices',
  stopRecording = 'stopRecording',
  pauseRecording = 'pauseRecording',
  resumeRecording = 'resumeRecording',
  duration = 'duration'
}

export const getCurrentMenuItem = (id: MenuItemId) => {
  return Menu.getApplicationMenu()?.getMenuItemById(id);
};
