import {Container} from 'unstated';

const defaultInputDeviceId = 'asd';

const SETTINGS_ANALYTICS_BLACKLIST = ['kapturesDir'];

export default class PreferencesContainer extends Container {
  state = {
    category: 'general',
    isMounted: false,
    shortcutMap: {},
    shortcuts: {},
    homePath: ''
  };

  mount = async setOverlay => {
    this.setOverlay = setOverlay;

    const [settingsStore, shortcuts, loginItemSettings, homePath] = await Promise.all([
      window.kap.ipc.invoke('settings:getAll'),
      window.kap.ipc.invoke('settings:getShortcuts'),
      window.kap.app.getLoginItemSettings(),
      window.kap.app.getPath('home')
    ]);

    this.setState({
      shortcuts: {},
      ...settingsStore,
      openOnStartup: loginItemSettings.openAtLogin,
      isMounted: true,
      shortcutMap: shortcuts,
      homePath
    });

    if (settingsStore.recordAudio) {
      this.getAudioDevices();
    }
  };

  getAudioDevices = async () => {
    const [audioDevices, defaultDevice, settingsStore] = await Promise.all([
      window.kap.ipc.invoke('devices:getAudioDevices'),
      window.kap.ipc.invoke('devices:getDefaultInputDevice'),
      window.kap.ipc.invoke('settings:getAll')
    ]);

    const {audioInputDeviceId} = settingsStore;
    const currentDefaultName = defaultDevice?.name;

    const updates = {
      audioDevices: [
        {name: `System Default${currentDefaultName ? ` (${currentDefaultName})` : ''}`, id: defaultInputDeviceId},
        ...audioDevices
      ],
      audioInputDeviceId
    };

    if (!audioDevices.some(device => device.id === audioInputDeviceId)) {
      updates.audioInputDeviceId = defaultInputDeviceId;
      await window.kap.ipc.invoke('settings:set', 'audioInputDeviceId', defaultInputDeviceId);
    }

    this.setState(updates);
  };

  setNavigation = ({category}) => {
    if (category) {
      this.setState({category});
    }
  };

  selectCategory = category => {
    this.setState({category});
  };

  toggleSetting = async (setting, value) => {
    const newValue = value === undefined ? !this.state[setting] : value;
    if (!SETTINGS_ANALYTICS_BLACKLIST.includes(setting)) {
      window.kap.ipc.invoke('analytics:track', `preferences/setting/${setting}/${newValue}`);
    }

    this.setState({[setting]: newValue});
    await window.kap.ipc.invoke('settings:set', setting, newValue);
  };

  toggleRecordAudio = async () => {
    const newValue = !this.state.recordAudio;
    window.kap.ipc.invoke('analytics:track', `preferences/setting/recordAudio/${newValue}`);

    if (!newValue || await window.kap.ipc.invoke('system:ensureMicrophonePermissions')) {
      if (newValue) {
        try {
          await this.getAudioDevices();
        } catch (error) {
          await window.kap.ipc.invoke('errors:show', error.message || String(error));
        }
      }

      this.setState({recordAudio: newValue});
      await window.kap.ipc.invoke('settings:set', 'recordAudio', newValue);
    }
  };

  toggleShortcuts = async () => {
    const setting = 'enableShortcuts';
    const newValue = !this.state[setting];
    this.toggleSetting(setting, newValue);
    await window.kap.ipc.invoke('toggle-shortcuts', {enabled: newValue});
  };

  updateShortcut = async (setting, shortcut) => {
    try {
      await window.kap.ipc.invoke('update-shortcut', {setting, shortcut});
      this.setState({
        shortcuts: {
          ...this.state.shortcuts,
          [setting]: shortcut
        }
      });
    } catch (error) {
      console.warn('Error updating shortcut', error);
    }
  };

  setOpenOnStartup = async value => {
    const openOnStartup = typeof value === 'boolean' ? value : !this.state.openOnStartup;
    this.setState({openOnStartup});
    await window.kap.app.setLoginItemSettings({openAtLogin: openOnStartup});
  };

  pickKapturesDir = async () => {
    const result = await window.kap.dialog.showOpenDialog({
      properties: [
        'openDirectory',
        'createDirectory'
      ]
    });

    if (!result.canceled && result.filePaths.length > 0) {
      this.toggleSetting('kapturesDir', result.filePaths[0]);
    }
  };

  setAudioInputDeviceId = async id => {
    this.setState({audioInputDeviceId: id});
    await window.kap.ipc.invoke('settings:set', 'audioInputDeviceId', id);
  };
}
