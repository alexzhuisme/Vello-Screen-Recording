import {UseConversionState} from 'hooks/editor/use-conversion';
import {ExportStatus} from 'common/types';

const ConversionDetails = ({conversion, showInFolder}: {conversion: UseConversionState; showInFolder: () => void}) => {
  const message = conversion?.message;
  const title = conversion?.titleWithFormat;
  const description = conversion?.description;
  const size = conversion?.fileSize;
  const showFinderButton = conversion?.status === ExportStatus.completed;

  return (
    <div className="conversion-details">
      <div className="message-row">
        <div className="message">{message}</div>
        {showFinderButton && (
          <div className="finder-button" onClick={showInFolder}>
            Show in Finder
          </div>
        )}
      </div>
      <div className="details">
        <div className="left">
          <div className="title" title={title} onClick={showInFolder}>{title}</div>
          <div className="description">{description}</div>
        </div>
        <div className="size">{size}</div>
      </div>
      <style jsx>{`
        .conversion-details {
          display: flex;
          height: fit-content;
          width: 100%;
          padding: 24px;
          flex-direction: column;
          color: var(--white);
          flex-shrink: 0;
          line-height: 16px;
        }

        .message-row {
          display: flex;
          align-items: center;
          justify-content: space-between;
          gap: 12px;
          padding-bottom: 24px;
          border-bottom: 1px solid #404040;
        }

        .message {
          color: #aaaaaa;
          font-size: 14px;
          min-width: 0;
        }

        .finder-button {
          flex-shrink: 0;
          height: 24px;
          color: white;
          padding: 4px 8px;
          background: #666666;
          border-radius: 4px;
          display: flex;
          align-items: center;
          justify-content: center;
          font-size: 12px;
          line-height: 16px;
          font-weight: 500;
          cursor: default;
        }

        .finder-button:active {
          background: hsla(0, 0%, 100%, 0.2);
          outline: none;
        }

        .details {
          padding-top: 24px;
          display: flex;
          line-height: 20px;
        }

        .left {
          flex: 1;
          display: flex;
          flex-direction: column;
          overflow: hidden;
        }

        .title {
          font-weight: 500;
          font-size: 14px;
          white-space: nowrap;
          overflow: hidden;
          text-overflow: ellipsis;
        }

        .description {
          color: #aaaaaa;
          font-size: 12px;
        }

        .size {
          font-size: 14px;
          flex-shrink: 0;
          margin-left: 8px;
        }
      `}</style>
    </div>
  );
};

export default ConversionDetails;
