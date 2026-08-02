import {app, BrowserWindow, ipcMain, Menu} from 'electron';
import pEvent from 'p-event';
import path from 'path';
import {customApplicationMenu, defaultApplicationMenu, MenuModifier} from '../menus/application';
import {loadRoute} from '../utils/routes';
import {sendToRenderer, callRenderer} from '../ipc-handlers';

interface KapWindowOptions<State> extends Electron.BrowserWindowConstructorOptions {
  route: string;
  waitForMount?: boolean;
  initialState?: State;
  menu?: MenuModifier;
  dock?: boolean;
}

app.on('browser-window-focus', (_, window) => {
  if (!KapWindow.fromId(window.id)) {
    Menu.setApplicationMenu(Menu.buildFromTemplate(defaultApplicationMenu()));
  }
});

ipcMain.handle('kap-window-mount', event => {
  const win = BrowserWindow.fromWebContents(event.sender);
  if (!win) {
    return;
  }

  const kapWindow = KapWindow.fromId(win.id);
  if (kapWindow) {
    kapWindow.onRendererMounted();
    return kapWindow.state;
  }
});

ipcMain.handle('kap-window-state', event => {
  const win = BrowserWindow.fromWebContents(event.sender);
  if (!win) {
    return;
  }

  return KapWindow.fromId(win.id)?.state;
});

export default class KapWindow<State = any> {
  static defaultOptions: Partial<KapWindowOptions<any>> = {
    waitForMount: true,
    dock: true,
    menu: defaultMenu => defaultMenu
  };

  private static readonly windows = new Map<number, KapWindow>();

  browserWindow: BrowserWindow;
  state?: State;
  menu: Menu = Menu.buildFromTemplate(defaultApplicationMenu());
  readonly id: number;

  private readonly readyPromise: Promise<void>;
  private readonly cleanupMethods: Array<() => void> = [];
  private readonly options: KapWindowOptions<State>;
  private mountResolver?: () => void;

  constructor(private readonly props: KapWindowOptions<State>) {
    const {
      route,
      waitForMount,
      initialState,
      ...rest
    } = props;

    this.browserWindow = new BrowserWindow({
      ...rest,
      webPreferences: {
        nodeIntegration: false,
        contextIsolation: true,
        preload: path.join(__dirname, '..', 'preload.js'),
        ...rest.webPreferences
      },
      show: false
    });

    this.id = this.browserWindow.id;
    KapWindow.windows.set(this.id, this);

    this.cleanupMethods = [];
    this.options = {
      ...KapWindow.defaultOptions,
      ...props
    };

    this.state = initialState;
    this.generateMenu();
    this.readyPromise = this.setupWindow();
  }

  static getAllWindows() {
    return [...this.windows.values()];
  }

  static fromId(id: number) {
    return this.windows.get(id);
  }

  get webContents() {
    return this.browserWindow.webContents;
  }

  cleanup = () => {
    KapWindow.windows.delete(this.id);

    for (const method of this.cleanupMethods) {
      method();
    }
  };

  onRendererMounted = () => {
    if (!this.browserWindow.isVisible()) {
      this.browserWindow.show();
    }

    this.mountResolver?.();
  };

  callRenderer = async <R = void>(channel: string, data?: any): Promise<R> => {
    return callRenderer<R>(this.browserWindow, channel, data);
  };

  sendToRenderer = (channel: string, data?: any): void => {
    sendToRenderer(this.browserWindow, channel, data);
  };

  setState = (partialState: State) => {
    this.state = {
      ...this.state,
      ...partialState
    };

    this.sendToRenderer('kap-window-state', this.state);
  };

  whenReady = async () => {
    return this.readyPromise;
  };

  private readonly generateMenu = () => {
    this.menu = Menu.buildFromTemplate(
      customApplicationMenu(this.options.menu!)
    );
  };

  private async setupWindow() {
    const {waitForMount} = this.options;

    KapWindow.windows.set(this.id, this);

    this.browserWindow.on('show', () => {
      if (this.options.dock && !app.dock.isVisible) {
        app.dock.show();
      }
    });

    // Only clean up on `closed`. If we also hook `close`, we run cleanup before
    // listeners can call `event.preventDefault()` (e.g. editor discard dialog),
    // which orphans the window in KapWindow.windows while it stays open.
    this.browserWindow.on('closed', this.cleanup);

    this.browserWindow.on('focus', () => {
      this.generateMenu();
      Menu.setApplicationMenu(this.menu);
    });

    this.webContents.on('did-finish-load', () => {
      if (!this.state) {
        return;
      }

      this.sendToRenderer('kap-window-state', this.state);
      // Send again after a short delay so the renderer (which sets up the listener in useEffect) receives it
      setTimeout(() => this.sendToRenderer('kap-window-state', this.state), 50);
      setTimeout(() => this.sendToRenderer('kap-window-state', this.state), 200);
    });

    loadRoute(this.browserWindow, this.props.route);

    if (waitForMount) {
      return new Promise<void>(resolve => {
        this.mountResolver = resolve;
      });
    }

    await pEvent(this.webContents, 'did-finish-load');
    this.browserWindow.show();
  }
}
