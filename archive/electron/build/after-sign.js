'use strict';

/**
 * Notarize Developer ID builds only. Mac App Store builds are re-signed by Apple
 * and must not go through notarization.
 */
module.exports = async context => {
  const appOutDir = String(context.appOutDir || '');
  const isMas = process.env.MAS_BUILD === '1' ||
    /[/\\]mas(-dev)?([/\\]|$)/i.test(appOutDir);

  if (isMas) {
    return;
  }

  return require('electron-builder-notarize')(context);
};
