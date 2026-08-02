import {useState, useEffect} from 'react';
import OptionsContainer from '../options-container';
import Select from './select';
import useConversionIdContext from 'hooks/editor/use-conversion-id';
import useEditorWindowState from 'hooks/editor/use-editor-window-state';
import VideoTimeContainer from '../video-time-container';
import VideoControlsContainer from '../video-controls-container';

const FormatSelect = () => {
  const {formats, format, updateFormat} = OptionsContainer.useContainer();
  const options = formats.map(format => ({label: format.prettyFormat, value: format.format}));

  return <Select options={options} value={format} onChange={updateFormat}/>;
};

const SaveFolderButton = () => {
  const [folder, setFolder] = useState('Downloads');

  useEffect(() => {
    const fetchDir = async () => {
      const dir = await window.kap.ipc.invoke('save:getDir') as string;
      setFolder(dir.split('/').pop() || 'Downloads');
    };

    fetchDir();
  }, []);

  const chooseFolder = async () => {
    const dir = await window.kap.ipc.invoke('save:chooseDir') as string;
    setFolder(dir.split('/').pop() || 'Downloads');
  };

  return (
    <button type="button" className="save-folder" onClick={chooseFolder}>
      Save to: {folder}
      <style jsx>{`
        .save-folder {
          padding: 4px 8px;
          background: rgba(255, 255, 255, 0.1);
          font-size: 12px;
          line-height: 12px;
          color: white;
          height: 24px;
          border-radius: 4px;
          text-align: center;
          border: none;
          box-shadow: inset 0px 1px 0px 0px rgba(255, 255, 255, 0.04), 0px 1px 2px 0px rgba(0, 0, 0, 0.2);
          margin-right: 8px;
          white-space: nowrap;
          max-width: 160px;
          overflow: hidden;
          text-overflow: ellipsis;
          cursor: pointer;
        }

        .save-folder:hover,
        .save-folder:focus {
          background: hsla(0, 0%, 100%, 0.2);
          outline: none;
        }
      `}</style>
    </button>
  );
};

const ConvertButton = () => {
  const {startConversion} = useConversionIdContext();
  const options = OptionsContainer.useContainer();
  const {filePath} = useEditorWindowState();
  const {startTime, endTime} = VideoTimeContainer.useContainer();
  const {isMuted} = VideoControlsContainer.useContainer();

  const onClick = () => {
    startConversion({
      filePath,
      conversionOptions: {
        width: options.width,
        height: options.height,
        startTime,
        endTime,
        fps: options.fps,
        shouldMute: isMuted,
        shouldCrop: true,
        editService: options.editPlugin ? {
          pluginName: options.editPlugin.pluginName,
          serviceTitle: options.editPlugin.title
        } : undefined
      },
      format: options.format,
      plugins: {
        share: {
          pluginName: '_saveToDisk',
          serviceTitle: 'Save to Disk'
        }
      }
    });
  };

  return (
    <>
      <button type="button" className="discard" onClick={async () => window.kap.window.close()}>
        Discard
      </button>
      <button type="button" className="start-export" onClick={onClick}>
        Convert
      </button>
      <style jsx>{`
        button {
          padding: 4px 8px;
          background: rgba(255, 255, 255, 0.1);
          font-size: 12px;
          line-height: 12px;
          color: white;
          height: 24px;
          border-radius: 4px;
          text-align: center;
          border: none;
          box-shadow: inset 0px 1px 0px 0px rgba(255, 255, 255, 0.04), 0px 1px 2px 0px rgba(0, 0, 0, 0.2);
        }

        button:hover,
        button:focus {
          background: hsla(0, 0%, 100%, 0.2);
          outline: none;
        }

        .discard {
          width: 72px;
          margin-right: 8px;
        }

        .start-export {
          width: 72px;
        }
      `}</style>
    </>
  );
};

const RightOptions = () => {
  return (
    <div className="container">
      <div className="format"><FormatSelect/></div>
      <SaveFolderButton/>
      <ConvertButton/>
      <style jsx>{`
          .container {
            height: 100%;
            display: flex;
            align-items: center;
          }

          .format {
            height: 24px;
            width: 112px;
            margin-right: 8px;
          }
        `}</style>
    </div>
  );
};

export default RightOptions;
