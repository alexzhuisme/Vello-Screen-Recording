import React from 'react';
import PropTypes from 'prop-types';

import {connect, PreferencesContainer} from '../../../containers';

import Item from '../item';
import Switch from '../item/switch';
import Select from '../item/select';
import ShortcutInput from '../shortcut-input';

import Category from './category';

class General extends React.Component {
  static defaultProps = {
    audioDevices: [],
    category: 'general'
  };

  state = {};

  async componentDidMount() {
    const showCursorSupported = await window.kap.ipc.invoke('system:macosVersion:isGreaterThanOrEqualTo', '10.13');
    this.setState({showCursorSupported});
  }

  render() {
    const {
      openOnStartup,
      showCursor,
      highlightClicks,
      enableShortcuts,
      loopExports,
      toggleSetting,
      toggleRecordAudio,
      audioInputDeviceId,
      setAudioInputDeviceId,
      audioDevices,
      recordAudio,
      setOpenOnStartup,
      updateShortcut,
      toggleShortcuts,
      category,
      lossyCompression,
      shortcuts,
      shortcutMap
    } = this.props;

    const {showCursorSupported} = this.state;

    const devices = audioDevices.map(device => ({
      label: device.name,
      value: device.id
    }));

    const tabIndex = category === 'general' ? 0 : -1;

    return (
      <Category>
        {
          showCursorSupported &&
          <Item
            key="showCursor"
            parentItem
            title="Show cursor"
            subtitle="Display the mouse cursor in your recordings"
          >
            <Switch
              tabIndex={tabIndex}
              checked={showCursor}
              onClick={
                () => {
                  if (showCursor) {
                    toggleSetting('highlightClicks', false);
                  }

                  toggleSetting('showCursor');
                }
              }/>
          </Item>
        }
        {
          showCursorSupported &&
          <Item key="highlightClicks" subtitle="Highlight clicks">
            <Switch
              tabIndex={tabIndex}
              checked={highlightClicks}
              disabled={!showCursor}
              onClick={() => toggleSetting('highlightClicks')}
            />
          </Item>
        }
        <Item
          key="enableShortcuts"
          parentItem
          title="Keyboard shortcuts"
          subtitle="Toggle and customise keyboard shortcuts"
          help="You can paste any valid Electron accelerator string like Command+Shift+5"
        >
          <Switch tabIndex={tabIndex} checked={enableShortcuts} onClick={toggleShortcuts}/>
        </Item>
        {
          enableShortcuts && Object.entries(shortcutMap ?? {}).map(([key, title]) => (
            <Item key={key} subtitle={title}>
              <ShortcutInput
                shortcut={shortcuts[key]}
                tabIndex={tabIndex}
                onChange={shortcut => updateShortcut(key, shortcut)}
              />
            </Item>
          ))
        }
        <Item
          key="loopExports"
          title="Loop exports"
          subtitle="Infinitely loop exports when supported"
        >
          <Switch tabIndex={tabIndex} checked={loopExports} onClick={() => toggleSetting('loopExports')}/>
        </Item>
        <Item
          key="recordAudio"
          parentItem
          title="Audio recording"
          subtitle="Record audio from input device"
        >
          <Switch
            tabIndex={tabIndex}
            checked={recordAudio}
            onClick={toggleRecordAudio}/>
        </Item>
        {
          recordAudio &&
          <Item key="audioInputDeviceId" subtitle="Select input device">
            <Select
              tabIndex={tabIndex}
              options={devices}
              selected={audioInputDeviceId}
              placeholder="Select Device"
              noOptionsMessage="No input devices"
              onSelect={setAudioInputDeviceId}/>
          </Item>
        }
        <Item
          key="openOnStartup"
          title="Start automatically"
          subtitle="Launch Vello on system startup"
        >
          <Switch tabIndex={tabIndex} checked={openOnStartup} onClick={setOpenOnStartup}/>
        </Item>
        <Item
          key="lossyCompression"
          parentItem
          title="Lossy GIF compression"
          subtitle="Smaller file size for a minor quality degradation."
        >
          <Switch
            tabIndex={tabIndex}
            checked={lossyCompression}
            onClick={() => toggleSetting('lossyCompression')}
          />
        </Item>
      </Category>
    );
  }
}

General.propTypes = {
  showCursor: PropTypes.bool,
  highlightClicks: PropTypes.bool,
  enableShortcuts: PropTypes.bool,
  toggleSetting: PropTypes.elementType.isRequired,
  toggleRecordAudio: PropTypes.elementType.isRequired,
  audioInputDeviceId: PropTypes.string,
  setAudioInputDeviceId: PropTypes.elementType.isRequired,
  audioDevices: PropTypes.array,
  recordAudio: PropTypes.bool,
  openOnStartup: PropTypes.bool,
  loopExports: PropTypes.bool,
  setOpenOnStartup: PropTypes.elementType.isRequired,
  updateShortcut: PropTypes.elementType.isRequired,
  toggleShortcuts: PropTypes.elementType.isRequired,
  category: PropTypes.string,
  shortcutMap: PropTypes.object,
  shortcuts: PropTypes.object,
  lossyCompression: PropTypes.bool
};

export default connect(
  [PreferencesContainer],
  ({
    showCursor,
    highlightClicks,
    recordAudio,
    enableShortcuts,
    audioInputDeviceId,
    audioDevices,
    openOnStartup,
    loopExports,
    category,
    lossyCompression,
    shortcuts,
    shortcutMap
  }) => ({
    showCursor,
    highlightClicks,
    recordAudio,
    enableShortcuts,
    audioInputDeviceId,
    audioDevices,
    openOnStartup,
    loopExports,
    category,
    lossyCompression,
    shortcuts,
    shortcutMap
  }),
  ({
    toggleSetting,
    toggleRecordAudio,
    setAudioInputDeviceId,
    setOpenOnStartup,
    updateShortcut,
    toggleShortcuts
  }) => ({
    toggleSetting,
    toggleRecordAudio,
    setAudioInputDeviceId,
    setOpenOnStartup,
    updateShortcut,
    toggleShortcuts
  })
)(General);
