import {app, BrowserWindow} from 'electron';

export const loadRoute = (window: BrowserWindow, routeName: string, {openDevTools}: {openDevTools?: boolean} = {}) => {
  if (app.isPackaged) {
    window.loadFile(`${app.getAppPath()}/renderer/out/${routeName}.html`);
    if (openDevTools) {
      window.webContents.openDevTools({mode: 'detach'});
    }
  } else {
    window.loadURL(`http://localhost:8000/${routeName}`);
    window.webContents.openDevTools({mode: 'detach'});
  }
};
