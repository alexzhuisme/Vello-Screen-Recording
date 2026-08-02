import {contextBridge, ipcRenderer, IpcRendererEvent} from 'electron';

type Listener = (...args: any[]) => void;

const kapApi = {
  ipc: {
    invoke: async (channel: string, ...args: any[]): Promise<any> =>
      ipcRenderer.invoke(channel, ...args),

    send: (channel: string, ...args: any[]): void =>
      ipcRenderer.send(channel, ...args),

    on: (channel: string, listener: Listener): (() => void) => {
      const wrapped = (_event: IpcRendererEvent, ...args: any[]) => listener(...args);
      ipcRenderer.on(channel, wrapped);
      return () => {
        ipcRenderer.removeListener(channel, wrapped);
      };
    },

    once: (channel: string, listener: Listener): void => {
      ipcRenderer.once(channel, (_event: IpcRendererEvent, ...args: any[]) => listener(...args));
    },

    onWithReply: (channel: string, handler: (data: any) => any | Promise<any>): (() => void) => {
      const wrapped = async (_event: IpcRendererEvent, data: any, requestId?: number) => {
        const result = await handler(data);
        if (requestId !== undefined) {
          ipcRenderer.send(`kap:reply:${channel}:${requestId}`, result);
        }
      };

      ipcRenderer.on(channel, wrapped);
      return () => {
        ipcRenderer.removeListener(channel, wrapped);
      };
    }
  },

  window: {
    close: async (): Promise<void> => ipcRenderer.invoke('kap:window:close'),
    minimize: async (): Promise<void> => ipcRenderer.invoke('kap:window:minimize'),
    maximize: async (): Promise<void> => ipcRenderer.invoke('kap:window:maximize'),
    show: async (): Promise<void> => ipcRenderer.invoke('kap:window:show'),
    focus: async (): Promise<void> => ipcRenderer.invoke('kap:window:focus'),
    getBounds: async (): Promise<{x: number; y: number; width: number; height: number}> =>
      ipcRenderer.invoke('kap:window:getBounds'),
    setBounds: async (bounds: any, animate?: boolean): Promise<void> =>
      ipcRenderer.invoke('kap:window:setBounds', bounds, animate),
    getSize: async (): Promise<number[]> => ipcRenderer.invoke('kap:window:getSize'),
    setSize: async (width: number, height: number): Promise<void> =>
      ipcRenderer.invoke('kap:window:setSize', width, height),
    setContentSize: async (width: number, height: number): Promise<void> =>
      ipcRenderer.invoke('kap:window:setContentSize', width, height),
    getContentSize: async (): Promise<number[]> => ipcRenderer.invoke('kap:window:getContentSize'),
    setResizable: async (resizable: boolean): Promise<void> =>
      ipcRenderer.invoke('kap:window:setResizable', resizable),
    setFullScreenable: async (fullscreenable: boolean): Promise<void> =>
      ipcRenderer.invoke('kap:window:setFullScreenable', fullscreenable),
    exitFullScreenIfNeeded: async (): Promise<void> =>
      ipcRenderer.invoke('kap:window:exitFullScreenIfNeeded'),
    setIgnoreMouseEvents: async (ignore: boolean, options?: any): Promise<void> =>
      ipcRenderer.invoke('kap:window:setIgnoreMouseEvents', ignore, options),
    isVisible: async (): Promise<boolean> => ipcRenderer.invoke('kap:window:isVisible')
  },

  system: {
    getAccentColor: async (): Promise<string> => ipcRenderer.invoke('kap:system:getAccentColor'),
    getColor: async (name: string): Promise<string> => ipcRenderer.invoke('kap:system:getColor', name),
    getUserDefault: async (key: string, type: string): Promise<any> =>
      ipcRenderer.invoke('kap:system:getUserDefault', key, type),
    isDarkMode: async (): Promise<boolean> => ipcRenderer.invoke('kap:system:isDarkMode'),
    onThemeChanged: (callback: Listener): (() => void) => {
      const wrapped = (_event: IpcRendererEvent, isDark: boolean) => callback(isDark);
      ipcRenderer.on('kap:system:theme-changed', wrapped);
      return () => {
        ipcRenderer.removeListener('kap:system:theme-changed', wrapped);
      };
    },
    onAccentColorChanged: (callback: Listener): (() => void) => {
      const wrapped = (_event: IpcRendererEvent, color: string) => callback(color);
      ipcRenderer.on('kap:system:accent-color-changed', wrapped);
      return () => {
        ipcRenderer.removeListener('kap:system:accent-color-changed', wrapped);
      };
    },
    subscribeNotification: async (name: string): Promise<number> =>
      ipcRenderer.invoke('kap:system:subscribeNotification', name),
    unsubscribeNotification: async (id: number): Promise<void> =>
      ipcRenderer.invoke('kap:system:unsubscribeNotification', id)
  },

  dialog: {
    showMessageBox: async (options: any): Promise<{response: number; checkboxChecked: boolean}> =>
      ipcRenderer.invoke('kap:dialog:showMessageBox', options),
    showMessageBoxSync: (options: any): number =>
      ipcRenderer.sendSync('kap:dialog:showMessageBoxSync', options),
    showOpenDialog: async (options: any): Promise<{canceled: boolean; filePaths: string[]}> =>
      ipcRenderer.invoke('kap:dialog:showOpenDialog', options),
    showSaveDialog: async (options: any): Promise<{canceled: boolean; filePath?: string}> =>
      ipcRenderer.invoke('kap:dialog:showSaveDialog', options)
  },

  shell: {
    openExternal: async (url: string): Promise<void> => ipcRenderer.invoke('kap:shell:openExternal', url),
    openPath: async (path: string): Promise<string> => ipcRenderer.invoke('kap:shell:openPath', path),
    showItemInFolder: async (path: string): Promise<void> =>
      ipcRenderer.invoke('kap:shell:showItemInFolder', path)
  },

  menu: {
    popup: async (template: any[], position?: {x: number; y: number}): Promise<any> =>
      ipcRenderer.invoke('kap:menu:popup', template, position)
  },

  app: {
    getVersion: async (): Promise<string> => ipcRenderer.invoke('kap:app:getVersion'),
    getName: async (): Promise<string> => ipcRenderer.invoke('kap:app:getName'),
    getPath: async (name: string): Promise<string> => ipcRenderer.invoke('kap:app:getPath', name),
    getLoginItemSettings: async (): Promise<any> => ipcRenderer.invoke('kap:app:getLoginItemSettings'),
    setLoginItemSettings: async (settings: any): Promise<void> =>
      ipcRenderer.invoke('kap:app:setLoginItemSettings', settings),
    quit: async (): Promise<void> => ipcRenderer.invoke('kap:app:quit')
  }
};

contextBridge.exposeInMainWorld('kap', kapApi);
