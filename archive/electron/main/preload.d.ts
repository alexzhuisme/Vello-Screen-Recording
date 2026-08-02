type Listener = (...args: any[]) => void;

interface KapIpc {
  invoke(channel: string, ...args: any[]): Promise<any>;
  send(channel: string, ...args: any[]): void;
  on(channel: string, listener: Listener): () => void;
  once(channel: string, listener: Listener): void;
  onWithReply(channel: string, handler: (data: any) => any | Promise<any>): () => void;
}

interface KapWindow {
  close(): Promise<void>;
  minimize(): Promise<void>;
  maximize(): Promise<void>;
  show(): Promise<void>;
  focus(): Promise<void>;
  getBounds(): Promise<{x: number; y: number; width: number; height: number}>;
  setBounds(bounds: Partial<{x: number; y: number; width: number; height: number}>, animate?: boolean): Promise<void>;
  getSize(): Promise<number[]>;
  setSize(width: number, height: number): Promise<void>;
  setContentSize(width: number, height: number): Promise<void>;
  getContentSize(): Promise<number[]>;
  setResizable(resizable: boolean): Promise<void>;
  setFullScreenable(fullscreenable: boolean): Promise<void>;
  exitFullScreenIfNeeded(): Promise<void>;
  setIgnoreMouseEvents(ignore: boolean, options?: {forward?: boolean}): Promise<void>;
  isVisible(): Promise<boolean>;
}

interface KapSystem {
  getAccentColor(): Promise<string>;
  getColor(name: string): Promise<string>;
  getUserDefault(key: string, type: string): Promise<any>;
  isDarkMode(): Promise<boolean>;
  onThemeChanged(callback: (isDark: boolean) => void): () => void;
  onAccentColorChanged(callback: (color: string) => void): () => void;
  subscribeNotification(name: string): Promise<number>;
  unsubscribeNotification(id: number): Promise<void>;
}

interface KapDialog {
  showMessageBox(options: any): Promise<{response: number; checkboxChecked: boolean}>;
  showMessageBoxSync(options: any): number;
  showOpenDialog(options: any): Promise<{canceled: boolean; filePaths: string[]}>;
  showSaveDialog(options: any): Promise<{canceled: boolean; filePath?: string}>;
}

interface KapShell {
  openExternal(url: string): Promise<void>;
  openPath(path: string): Promise<string>;
  showItemInFolder(path: string): Promise<void>;
}

interface KapMenu {
  popup(template: any[], position?: {x: number; y: number}): Promise<any>;
}

interface KapApp {
  getVersion(): Promise<string>;
  getName(): Promise<string>;
  getPath(name: string): Promise<string>;
  getLoginItemSettings(): Promise<any>;
  setLoginItemSettings(settings: any): Promise<void>;
  quit(): Promise<void>;
}

interface KapApi {
  ipc: KapIpc;
  window: KapWindow;
  system: KapSystem;
  dialog: KapDialog;
  shell: KapShell;
  menu: KapMenu;
  app: KapApp;
}

declare global {
  interface Window {
    kap: KapApi;
  }
}

export {};
