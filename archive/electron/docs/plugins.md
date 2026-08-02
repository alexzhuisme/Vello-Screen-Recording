# Plugins

Vello no longer supports the npm-based plugin system that was originally documented here. The only export target shipped today is the built-in **Save to Disk** plugin (`main/export/builtin-save-plugin.ts`), which is bundled with the app and does not require installation.

If you want to add additional export targets, do so by extending the in-tree plugin scaffolding under `main/plugins` and `main/export` and registering a new built-in service.

For historical reference, the original Kap plugin documentation is available in the [upstream Kap repository](https://github.com/wulkano/kap).
