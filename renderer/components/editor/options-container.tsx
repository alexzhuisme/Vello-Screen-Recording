import {useState, useEffect, useMemo} from 'react';
import {createContainer} from 'unstated-next';
import {debounce, DebouncedFunc} from 'lodash';

import VideoMetadataContainer from './video-metadata-container';
import VideoControlsContainer from './video-controls-container';
import useEditorOptions, {EditorOptionsState} from 'hooks/editor/use-editor-options';
import {Format, App} from 'common/types';
import useEditorWindowState from 'hooks/editor/use-editor-window-state';

type EditService = EditorOptionsState['editServices'][0];

type SharePlugin = {
  pluginName: string;
  serviceTitle: string;
  app?: App;
};

const isFormatMuted = (format: Format) => ['gif', 'apng'].includes(format);

const EXPORT_FPS_CHOICES = [30, 60] as const;
type ExportFpsChoice = (typeof EXPORT_FPS_CHOICES)[number];

/** Picks 30 or 60, nearest to the hint (history / source fps). */
const resolveExportFps = (originalFps: number, preferred?: number): number => {
  const hint = preferred ?? Math.min(originalFps, 60);

  let best: ExportFpsChoice = EXPORT_FPS_CHOICES[0];
  for (const n of EXPORT_FPS_CHOICES) {
    if (Math.abs(n - hint) < Math.abs(best - hint)) {
      best = n;
    }
  }

  return best;
};

const useOptions = () => {
  const {fps: originalFps} = useEditorWindowState();
  const {
    state: {
      formats,
      fpsHistory,
      editServices
    },
    updateFpsUsage,
    isLoading
  } = useEditorOptions();

  const metadata = VideoMetadataContainer.useContainer();
  const {isMuted, mute, unmute} = VideoControlsContainer.useContainer();

  const [format, setFormat] = useState<Format>();
  const [fps, setFps] = useState<number>();
  const [width, setWidth] = useState<number>();
  const [height, setHeight] = useState<number>();
  const [editPlugin, setEditPlugin] = useState<EditService>();
  const [sharePlugin, setSharePlugin] = useState<SharePlugin>();

  const [wasMuted, setWasMuted] = useState(false);

  const debouncedUpdateFpsUsage = useMemo(() => {
    if (!updateFpsUsage) {
      return;
    }

    return debounce(updateFpsUsage, 1000);
  }, [updateFpsUsage]);

  const updateFps = (newFps: number, formatName = format) => {
    setFps(newFps);
    debouncedUpdateFpsUsage?.({format: formatName, fps: newFps});
  };

  const updateSharePlugin = (plugin: SharePlugin) => {
    setSharePlugin(plugin);
  };

  const updateFormat = (formatName: Format) => {
    debouncedUpdateFpsUsage?.flush();

    if (metadata.hasAudio) {
      if (isFormatMuted(formatName) && !isFormatMuted(format)) {
        setWasMuted(isMuted);
        mute();
      } else if (!isFormatMuted(formatName) && isFormatMuted(format) && !wasMuted) {
        unmute();
      }
    }

    const formatOption = formats.find(f => f.format === formatName);
    if (!formatOption) {
      return;
    }

    const selectedSharePlugin = formatOption.plugins.find(plugin => {
      return (
        plugin.pluginName === sharePlugin?.pluginName &&
        plugin.title === sharePlugin?.serviceTitle &&
        (plugin.apps?.some(app => app.url === sharePlugin?.app?.url) ?? true)
      );
    }) ?? formatOption.plugins[0];

    setFormat(formatName);

    if (!selectedSharePlugin) {
      setSharePlugin(undefined);
      updateFps(resolveExportFps(originalFps, fpsHistory[formatName]), formatName);
      return;
    }

    setSharePlugin({
      pluginName: selectedSharePlugin.pluginName,
      serviceTitle: selectedSharePlugin.title,
      app: selectedSharePlugin.apps?.find(app => app.url === sharePlugin?.app?.url)
    });
    updateFps(resolveExportFps(originalFps, fpsHistory[formatName]), formatName);
  };

  useEffect(() => {
    if (isLoading) {
      return;
    }

    const firstFormat = formats[0];
    const formatName = firstFormat.format;

    setFormat(formatName);

    const firstPlugin = firstFormat.plugins[0];

    setSharePlugin(firstPlugin && {
      pluginName: firstPlugin.pluginName,
      serviceTitle: firstPlugin.title
    });

    updateFps(resolveExportFps(originalFps, fpsHistory[formatName]), formatName);
  }, [isLoading]);

  useEffect(() => {
    setWidth(metadata.width);
    setHeight(metadata.height);
  }, [metadata]);

  useEffect(() => {
    if (!editPlugin) {
      return;
    }

    const newPlugin = editServices.find(service => service.pluginName === editPlugin.pluginName && service.title === editPlugin.title);
    setEditPlugin(newPlugin);
  }, [editServices]);

  const setDimensions = (dimensions: {width: number; height: number}) => {
    setWidth(dimensions.width);
    setHeight(dimensions.height);
  };

  return {
    width,
    height,
    format,
    fps,
    originalFps,
    editPlugin,
    formats,
    editServices,
    sharePlugin,
    updateSharePlugin,
    updateFps,
    updateFormat,
    setEditPlugin,
    setDimensions
  };
};

const OptionsContainer = createContainer(useOptions);

export default OptionsContainer;
