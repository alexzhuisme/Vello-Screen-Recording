import {RemoteState, getChannelNames} from './utils';
import {ipcMain, BrowserWindow} from 'electron';
import {sendToRenderer} from '../ipc-handlers';

// eslint-disable-next-line @typescript-eslint/ban-types
const setupRemoteState = async <State, Actions extends Record<string, Function>>(name: string, callback: RemoteState<State, Actions>) => {
  const channelNames = getChannelNames(name);

  const renderersMap = new Map<string, Set<BrowserWindow>>();

  const sendUpdate = async (state?: State, id?: string) => {
    if (id) {
      const renderers = renderersMap.get(id) ?? new Set();

      for (const renderer of renderers) {
        sendToRenderer(renderer, channelNames.stateUpdated, {state, id});
      }

      return;
    }

    for (const [windowId, renderers] of renderersMap.entries()) {
      for (const renderer of renderers) {
        if (renderer && !renderer.isDestroyed()) {
          sendToRenderer(renderer, channelNames.stateUpdated, {state: state ?? (await getState?.(windowId))});
        } else {
          renderers.delete(renderer);
        }
      }
    }
  };

  const {getState, actions = {}, subscribe} = await callback(sendUpdate);

  ipcMain.handle(channelNames.subscribe, (event, customId: string) => {
    const window = BrowserWindow.fromWebContents(event.sender)!;
    const id = customId ?? window.id.toString();

    if (!renderersMap.has(id)) {
      renderersMap.set(id, new Set());
    }

    renderersMap.get(id)?.add(window);
    const unsubscribe = subscribe?.(id);

    window.on('close', () => {
      renderersMap.get(id)?.delete(window);
      unsubscribe?.();
    });

    return Object.keys(actions);
  });

  ipcMain.handle(channelNames.getState, async (event, customId: string) => {
    const window = BrowserWindow.fromWebContents(event.sender)!;
    const id = customId ?? window.id.toString();
    return getState(id);
  });

  ipcMain.handle(channelNames.callAction, (event, {key, data, id: customId}: any) => {
    const window = BrowserWindow.fromWebContents(event.sender)!;
    const id = customId || window.id.toString();
    return (actions as any)[key]?.(id, ...data);
  });
};

export default setupRemoteState;
