import {ExportStatus} from 'common/types';
import useConversion from 'hooks/editor/use-conversion';
import useConversionIdContext from 'hooks/editor/use-conversion-id';
import {useConfirmation} from 'hooks/use-confirmation';
import {useMemo} from 'react';
import {useKeyboardAction} from '../../../hooks/use-keyboard-action';
import ConversionDetails from './conversion-details';
import TitleBar from './title-bar';
import VideoPreview from './video-preview';

const dialogOptions = {
  message: 'Are you sure you want to discard this conversion?',
  detail: 'Any progress will be lost.',
  confirmButtonText: 'Discard'
};

const EditorConversionView = ({conversionId}: {conversionId: string}) => {
  const {setConversionId} = useConversionIdContext();
  const conversion = useConversion(conversionId);

  const inProgress = conversion.state?.status === ExportStatus.inProgress;

  const cancel = () => {
    if (inProgress) {
      conversion.cancel();
    }
  };

  const safeCancel = useConfirmation(cancel, dialogOptions);

  const cancelAndGoBack = () => {
    cancel();
    setConversionId('');
  };

  const finalCancel = useMemo(() => inProgress ? safeCancel : () => { /* do nothing */ }, [inProgress]);

  useKeyboardAction('Escape', finalCancel);

  const showInFolder = () => conversion.showInFolder();

  return (
    <div className="editor-conversion-view">
      <div className="editor-conversion-view-inner">
        <TitleBar
          conversion={conversion.state}
          cancel={cancelAndGoBack}
          retry={() => {
            conversion.retry();
          }}/>
        <VideoPreview conversion={conversion.state} cancel={finalCancel} showInFolder={showInFolder}/>
        <ConversionDetails conversion={conversion.state} showInFolder={showInFolder}/>
      </div>
      <style jsx>{`
        .editor-conversion-view {
          width: 100%;
          flex: 1;
          display: flex;
          justify-content: center;
          -webkit-app-region: no-drag;
        }

        .editor-conversion-view-inner {
          width: 100%;
          max-width: 370px;
          align-self: stretch;
          display: flex;
          flex-direction: column;
        }
      `}</style>
    </div>
  );
};

export default EditorConversionView;
