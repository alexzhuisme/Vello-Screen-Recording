import path from 'path';
import {homedir} from 'os';
import {app} from 'electron';
import {settings} from '../common/settings';
import {isMas} from './is-mas';

/**
 * Start access to the user-selected recordings directory via a security-scoped
 * bookmark (required for persistent paths outside the container on MAS).
 * Returns a stop function that must be called when finished.
 */
const noop = (): void => {
  // Intentionally empty
};

export const startAccessingKapturesDir = (): (() => void) => {
  if (!isMas) {
    return noop;
  }

  const bookmark = settings.get('kapturesDirBookmark');
  if (!bookmark) {
    return noop;
  }

  try {
    const stop = app.startAccessingSecurityScopedResource(bookmark);
    return () => {
      stop();
    };
  } catch (error) {
    console.warn('Failed to start accessing security-scoped recordings directory', error);
    return noop;
  }
};

export const ensureDefaultKapturesDirForMas = (): void => {
  if (!isMas) {
    return;
  }

  const current = settings.get('kapturesDir');
  const legacyDefault = path.join(homedir(), 'Movies', 'Vello Recordings');

  // Migrate first-run / legacy defaults to the sandbox-aware videos path
  if (!current || current === legacyDefault) {
    try {
      settings.set('kapturesDir', path.join(app.getPath('videos'), 'Vello Recordings'));
    } catch {
      settings.set('kapturesDir', path.join(app.getPath('userData'), 'Recordings'));
    }
  }
};
