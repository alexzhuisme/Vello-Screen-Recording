import PluginConfig from '../plugins/config';
import {saveToDiskShareService} from './save-to-disk';
import {ShareService} from '../plugins/service';
import type {PluginContextRef} from '../plugins/service-context';

/**
 * Single built-in “export target” bundled with Vello (no npm/yarn plugin system).
 */
export class BuiltinSaveToDiskPlugin implements PluginContextRef {
  readonly config: PluginConfig;

  constructor() {
    this.config = new PluginConfig('_saveToDisk', [saveToDiskShareService] as ShareService[]);
  }

  get name(): string {
    return '_saveToDisk';
  }

  get isBuiltIn(): boolean {
    return true;
  }

  get pluginPath(): string {
    return '';
  }

  get shareServices(): ShareService[] {
    return [saveToDiskShareService];
  }

  get prettyName(): string {
    return 'Save to Disk';
  }
}

export const builtinSavePlugin = new BuiltinSaveToDiskPlugin();
