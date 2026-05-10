import Head from 'next/head';
import {useEffect} from 'react';
// Import EditorPreview from '../components/editor/editor-preview';
import combineUnstatedContainers from '../utils/combine-unstated-containers';
import VideoMetadataContainer from '../components/editor/video-metadata-container';
import VideoTimeContainer from '../components/editor/video-time-container';
import VideoControlsContainer from '../components/editor/video-controls-container';
import OptionsContainer from '../components/editor/options-container';
import useEditorWindowState from 'hooks/editor/use-editor-window-state';
import {ConversionIdContextProvider} from 'hooks/editor/use-conversion-id';
import Editor from 'components/editor';

const ContainerProvider = combineUnstatedContainers([
  OptionsContainer,
  VideoMetadataContainer,
  VideoTimeContainer,
  VideoControlsContainer
]) as any;

const EditorPage = () => {
  const args = useEditorWindowState();

  useEffect(() => {
    if (args) {
      window.kap.ipc.invoke('kap-window-mount');
    }
  }, [args]);

  if (!args) {
    return null;
  }

  return (
    <div className="cover-window">
      <Head>
        <meta httpEquiv="Content-Security-Policy" content="media-src file:;"/>
      </Head>
      <ConversionIdContextProvider>
        <ContainerProvider>
          <Editor/>
        </ContainerProvider>
      </ConversionIdContextProvider>
      <style jsx global>{`
        html,
        body,
        #__next,
        .cover-window {
          margin: 0;
          padding: 0;
          width: 100%;
          height: 100%;
          overflow: hidden;
        }

        #__next {
          display: flex;
          flex-direction: column;
          min-width: 0;
          min-height: 0;
        }

        .cover-window {
          display: flex;
          flex-direction: column;
          flex: 1;
          min-width: 0;
          min-height: 0;
          -webkit-app-region: drag;
          user-select: none;
          background-color: #222222;
        }

        :root {
          --slider-popup-background: rgba(255, 255, 255, 0.85);
          --slider-background-color: #ffffff;
          --slider-thumb-color: #ffffff;
          --background-color: #222222;
        }

        .dark {
          --slider-popup-background: #222222;
          --slider-background-color: var(--input-background-color);
          --slider-thumb-color: var(--storm);
        }

      `}</style>
    </div>
  );
};

export default EditorPage;
