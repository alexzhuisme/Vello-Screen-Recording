import {useMemo} from 'react';
import OptionsContainer from '../options-container';
import VideoMetadataContainer from '../video-metadata-container';
import Select from './select';

const percentValues = [100, 75, 50, 33, 25, 20, 10];

const LeftOptions = () => {
  const {width, height, setDimensions, fps, updateFps} = OptionsContainer.useContainer();
  const metadata = VideoMetadataContainer.useContainer();

  const percentOptions = useMemo(() => {
    const ratio = metadata.width / metadata.height;

    const options = percentValues.map(percent => {
      const adjustedWidth = Math.round(metadata.width * (percent / 100));
      const adjustedHeight = Math[ratio > 1 ? 'ceil' : 'floor'](adjustedWidth / ratio);

      return {
        label: `${adjustedWidth} x ${adjustedHeight} (${percent === 100 ? 'Original' : `${percent}%`})`,
        value: {width: adjustedWidth, height: adjustedHeight},
        checked: width === adjustedWidth
      };
    });

    if (options.every(opt => !opt.checked)) {
      return [
        {
          label: 'Custom',
          value: {width, height},
          checked: true
        },
        {
          separator: true
        },
        ...options
      ];
    }

    return options;
  }, [metadata, width, height]);

  const selectPercentage = updates => {
    setDimensions(updates);
  };

  const percentLabel = `${Math.round((width / metadata.width) * 100)}%`;

  const fpsOptions = useMemo(
    () =>
      [30, 60].map(n => ({
        label: String(n),
        value: n,
        checked: fps === n
      })),
    [fps]
  );

  return (
    <div className="container">
      <div className="percent">
        <Select options={percentOptions as any} customLabel={percentLabel} onChange={selectPercentage}/>
      </div>
      <div className="fps">
        <Select
          value={fps}
          options={fpsOptions as any}
          customLabel={fps === undefined ? '' : String(fps)}
          onChange={value => {
            if (typeof value === 'number') {
              updateFps(value);
            }
          }}
        />
      </div>
      <style jsx>{`
          .container {
            height: 100%;
            display: flex;
            align-items: center;
          }

          .percent {
            height: 24px;
            width: 68px;
            margin-right: 8px;
          }

          .fps {
            height: 24px;
            width: 52px;
            margin-left: 8px;
          }

          .option {
            width: 48px;
            height: 22px;
            background: transparent;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 12px;
            color: white;
            box-sizing: border-box;
          }

          .option:hover {
            background: hsla(0, 0%, 100%, 0.2);
          }

          .option:active,
          .option.selected {
            background: transparent;
          }
        `}</style>
    </div>
  );
};

export default LeftOptions;
