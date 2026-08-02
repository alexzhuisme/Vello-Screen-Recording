import {BrowserWindow} from 'electron';

/** Fullscreen sheet/close issues are macOS-specific; skip work on other platforms. */
const isMacOS = process.platform === 'darwin';

/**
 * Leave native fullscreen. macOS sheet dialogs (e.g. `showMessageBox` with a parent window)
 * are often invisible while the parent is fullscreen; exiting first fixes that.
 * Closing while still fullscreen can also hang — callers should await this before `close()`.
 */
export const exitFullScreenIfNeeded = async (window: BrowserWindow | null | undefined): Promise<void> => {
  if (!isMacOS || !window || window.isDestroyed() || !window.isFullScreen()) {
    return;
  }

  await new Promise<void>(resolve => {
    let settled = false;
    const finish = () => {
      if (settled || window.isDestroyed()) {
        return;
      }

      settled = true;
      clearTimeout(fallbackTimer);
      window.removeListener('leave-full-screen', onLeaveFullScreen);
      setTimeout(resolve, 0);
    };

    const onLeaveFullScreen = () => {
      finish();
    };

    const fallbackTimer = setTimeout(finish, 5000);
    window.once('leave-full-screen', onLeaveFullScreen);
    window.setFullScreen(false);
  });
};

/** Prefer this over `BrowserWindow.close()` when the window may be fullscreen (macOS). */
export const closeBrowserWindowSafely = (window: BrowserWindow | null | undefined): void => {
  if (!window || window.isDestroyed()) {
    return;
  }

  if (!isMacOS || !window.isFullScreen()) {
    window.close();
    return;
  }

  void (async () => {
    await exitFullScreenIfNeeded(window);
    if (!window.isDestroyed()) {
      // Defer past the fullscreen transition (see electron/electron#25422).
      setTimeout(() => {
        if (!window.isDestroyed()) {
          window.close();
        }
      }, 0);
    }
  })();
};
