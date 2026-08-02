const path = require('path');

// Static export is loaded via file:// in the packaged app. Absolute paths like
// /_next/static/... resolve to the filesystem root and scripts never load, so
// the cropper (and other windows) appear blank in production. Relative paths
// fix loading when ELECTRON_STATIC_EXPORT is set during `yarn build-renderer`.
const assetPrefix =
  process.env.ELECTRON_STATIC_EXPORT === '1' ? './' : '';

module.exports = (nextConfig) => {
  return Object.assign({}, nextConfig, {
    assetPrefix,
    webpack(config, options) {
      config.module.rules.push({
        test: /\.+(js|jsx|mjs|ts|tsx)$/,
        loader: options.defaultLoaders.babel,
        include: [
          path.join(__dirname, '..', 'main', 'common')
        ]
      });

      config.devtool = 'cheap-module-source-map';

      // Stub Node built-ins in client bundle (deps like atomically require 'fs')
      if (!options.isServer) {
        config.node = {
          ...config.node,
          fs: 'empty',
          path: 'empty',
          net: 'empty',
          tls: 'empty'
        };
      }

      if (typeof nextConfig.webpack === 'function') {
        return nextConfig.webpack(config, options);
      }

      return config;
    }
  })
}
