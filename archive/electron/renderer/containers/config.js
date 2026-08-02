import {Container} from 'unstated';

export default class ConfigContainer extends Container {
  state = {selectedTab: 0};

  setPlugin = async pluginName => {
    const {validators, values} = await window.kap.ipc.invoke('plugins:getConfig', pluginName);
    this.pluginName = pluginName;
    this.setState({
      validators,
      values,
      pluginName
    });
  };

  setEditService = async (pluginName, serviceTitle) => {
    const {validators, values} = await window.kap.ipc.invoke('plugins:getConfig', pluginName);
    this.pluginName = pluginName;
    this.serviceTitle = serviceTitle;
    const filteredValidators = validators.filter(({title}) => title === serviceTitle);
    this.setState({
      validators: filteredValidators,
      values,
      pluginName,
      serviceTitle
    });
  };

  closeWindow = () => window.kap.window.close();

  openConfig = () => window.kap.ipc.invoke('plugins:openConfigInEditor', this.pluginName);

  viewOnGithub = () => window.kap.ipc.invoke('plugins:viewOnGithub', this.pluginName);

  onChange = async (key, value) => {
    await window.kap.ipc.invoke('plugins:setConfig', this.pluginName, key, value);
    const {validators, values} = await window.kap.ipc.invoke('plugins:getConfig', this.pluginName);

    if (this.serviceTitle) {
      const filteredValidators = validators.filter(({title}) => title === this.serviceTitle);
      this.setState({validators: filteredValidators, values});
    } else {
      this.setState({validators, values});
    }
  };

  selectTab = selectedTab => {
    this.setState({selectedTab});
  };
}
