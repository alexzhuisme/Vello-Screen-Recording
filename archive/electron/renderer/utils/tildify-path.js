/**
 * Replace the user home directory prefix with `~` (browser-safe; no Node `path`/`os`).
 * `homePath` should come from `app.getPath('home')` via IPC.
 */
export const tildifyPath = (absolutePath, homePath) => {
  if (!absolutePath || typeof absolutePath !== 'string') {
    return '';
  }

  if (!homePath || typeof homePath !== 'string') {
    return absolutePath;
  }

  const home = homePath.replace(/\/+$/, '');
  const normalized = absolutePath.replace(/\\/g, '/').replace(/\/+$/, '');

  if (normalized === home) {
    return '~';
  }

  const prefix = `${home}/`;
  if (normalized.startsWith(prefix)) {
    return `~/${normalized.slice(prefix.length)}`;
  }

  return absolutePath;
};
