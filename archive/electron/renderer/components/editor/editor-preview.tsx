import TrafficLights from '../traffic-lights';
import VideoPlayer from './video-player';
import Options from './options';
import useEditorWindowState from 'hooks/editor/use-editor-window-state';
import {useState, useRef, useEffect, useCallback} from 'react';

const TOP_BAR_HIDE_DELAY_MS = 320;

const EditorPreview = () => {
  const {title = 'Editor', previewFilePath} = useEditorWindowState();
  const isPreviewReady = Boolean(previewFilePath);
  const [topBarVisible, setTopBarVisible] = useState(false);
  const hideTimerRef = useRef<ReturnType<typeof setTimeout>>();

  const clearHideTimer = useCallback(() => {
    if (hideTimerRef.current !== undefined) {
      clearTimeout(hideTimerRef.current);
      hideTimerRef.current = undefined;
    }
  }, []);

  const scheduleHide = useCallback(() => {
    clearHideTimer();
    hideTimerRef.current = setTimeout(() => {
      setTopBarVisible(false);
      hideTimerRef.current = undefined;
    }, TOP_BAR_HIDE_DELAY_MS);
  }, [clearHideTimer]);

  const onTopZoneEnter = useCallback(() => {
    clearHideTimer();
    setTopBarVisible(true);
  }, [clearHideTimer]);

  const onTopZoneLeave = useCallback((event: React.MouseEvent<HTMLDivElement>) => {
    // While a mouse button is held (window drag in progress), Chromium fires bogus
    // `mouseleave` as the window moves under the cursor — that would hide the bar
    // mid-drag and feel broken.
    if (event.buttons !== 0) {
      return;
    }

    // Once `.title-bar.is-visible` becomes a drag region, moving onto it triggers
    // `mouseleave` on this strip even though the cursor is still inside its bounds.
    // Treat that as "still hovering" so the bar doesn't flicker.
    const rect = event.currentTarget.getBoundingClientRect();
    const stillInside =
      event.clientX >= rect.left &&
      event.clientX <= rect.right &&
      event.clientY >= rect.top &&
      event.clientY <= rect.bottom;

    if (stillInside) {
      return;
    }

    scheduleHide();
  }, [scheduleHide]);

  // Safety net: when the user is dragging and lifts the button outside the strip,
  // re-evaluate visibility instead of leaving the bar stuck open.
  useEffect(() => {
    const onMouseUp = () => {
      if (!topBarVisible) {
        return;
      }

      scheduleHide();
    };

    window.addEventListener('mouseup', onMouseUp);
    return () => window.removeEventListener('mouseup', onMouseUp);
  }, [topBarVisible, scheduleHide]);

  useEffect(() => () => clearHideTimer(), [clearHideTimer]);

  return (
    <div className="preview-container">
      <div className="preview-hover-container">
        <div
          className="top-title-hover-zone"
          onMouseEnter={onTopZoneEnter}
          onMouseLeave={onTopZoneLeave}
        >
          <div className={`title-bar${topBarVisible ? ' is-visible' : ''}`}>
            <div className="title-bar-container">
              <TrafficLights/>
              <div className="title">{title}</div>
            </div>
          </div>
        </div>
        {
          isPreviewReady ?
            <VideoPlayer/> :
            <div className="preview-loading">
              <div className="spinner"/>
              <div className="loading-label">Preparing preview…</div>
            </div>
        }
      </div>
      {isPreviewReady && <Options/>}
      <style jsx>{`
        .preview-container {
          display: flex;
          flex-direction: column;
          flex: 1;
          min-height: 0;
        }

        .preview-hover-container {
          display: flex;
          flex: 1;
          min-height: 0;
          flex-direction: column;
          position: relative;
          overflow: hidden;
        }

        /* Hover detection requires DOM mouse events to fire reliably, which they only
           do over a no-drag region. The window itself is still draggable from the video
           area (.cover-window is drag in editor.tsx), and from the visible glass bar
           below — so users always have a draggable surface. */
        .top-title-hover-zone {
          position: absolute;
          top: 0;
          left: 0;
          width: 100%;
          height: 36px;
          z-index: 11;
          pointer-events: auto;
          -webkit-app-region: no-drag;
        }

        .title-bar {
          position: absolute;
          top: 0;
          left: 0;
          width: 100%;
          height: 36px;
          background: rgba(0, 0, 0, 0.2);
          backdrop-filter: blur(20px);
          display: flex;
          transform: translateY(-100%);
          opacity: 0;
          transition: transform 0.12s ease-in-out, opacity 0.12s ease-in-out;
          pointer-events: none;
        }

        .title-bar.is-visible {
          transform: translateY(0);
          opacity: 1;
          pointer-events: auto;
          -webkit-app-region: drag;
        }

        .title-bar-container {
          flex: 1;
          height: 100%;
          display: flex;
          align-items: center;
        }

        .title {
          width: 100%;
          height: 100%;
          display: flex;
          align-items: center;
          justify-content: center;
          font-size: 1.4rem;
          color: #fff;
          margin-left: -72px;
        }

        .preview-loading {
          flex: 1;
          min-height: 0;
          display: flex;
          flex-direction: column;
          align-items: center;
          justify-content: center;
          gap: 12px;
          color: rgba(255, 255, 255, 0.9);
          font-size: 13px;
          letter-spacing: 0.2px;
        }

        .spinner {
          width: 20px;
          height: 20px;
          border-radius: 50%;
          border: 2px solid rgba(255, 255, 255, 0.2);
          border-top-color: rgba(255, 255, 255, 0.85);
          animation: spin 0.8s linear infinite;
        }

        @keyframes spin {
          to {
            transform: rotate(360deg);
          }
        }
      `}</style>
    </div>
  );
};

export default EditorPreview;
