/**
 * Renderer-only flags API via IPC. Do not import main/common/flags in the renderer.
 */

export const flags = {
  get: async (key: string): Promise<unknown> =>
    window.kap.ipc.invoke('flags:get', key),

  set: async (key: string, value: unknown): Promise<void> =>
    window.kap.ipc.invoke('flags:set', key, value)
};
