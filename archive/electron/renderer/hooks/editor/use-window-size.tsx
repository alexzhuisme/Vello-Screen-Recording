import {useEffect, useRef} from 'react';
import {resizeKeepingCenter} from 'utils/window';

const CONVERSION_WIDTH = 370;
const CONVERSION_HEIGHT = 392;
const DEFAULT_EDITOR_WIDTH = 768;
const DEFAULT_EDITOR_HEIGHT = 480;

export const useEditorWindowSizeEffect = (isConversionWindowState: boolean) => {
  const previousWindowSizeRef = useRef<{width: number; height: number} | undefined>(undefined);
  const isConversionRef = useRef(isConversionWindowState);

  useEffect(() => {
    isConversionRef.current = isConversionWindowState;
  }, [isConversionWindowState]);

  useEffect(() => {
    const update = async () => {
      const bounds = await window.kap.window.getBounds();

      if (isConversionWindowState) {
        previousWindowSizeRef.current = {width: bounds.width, height: bounds.height};
        await window.kap.window.exitFullScreenIfNeeded();
        await window.kap.window.setBounds(resizeKeepingCenter(bounds, {width: CONVERSION_WIDTH, height: CONVERSION_HEIGHT}), true);
        await window.kap.window.setResizable(false);
        await window.kap.window.setFullScreenable(false);
      } else {
        const size = previousWindowSizeRef.current ?? {width: DEFAULT_EDITOR_WIDTH, height: DEFAULT_EDITOR_HEIGHT};
        if (previousWindowSizeRef.current) {
          await window.kap.window.setResizable(true);
          await window.kap.window.setFullScreenable(true);
          await window.kap.window.setBounds(resizeKeepingCenter(bounds, size), true);
        } else {
          previousWindowSizeRef.current = {width: bounds.width, height: bounds.height};
        }
      }
    };

    update();
  }, [isConversionWindowState]);

  useEffect(() => {
    const syncBounds = async () => {
      if (isConversionRef.current) {
        return;
      }

      const bounds = await window.kap.window.getBounds();
      previousWindowSizeRef.current = {width: bounds.width, height: bounds.height};
    };

    window.addEventListener('resize', syncBounds);
    return () => {
      window.removeEventListener('resize', syncBounds);
    };
  }, []);
};
