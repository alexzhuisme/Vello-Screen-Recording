import {useEffect} from 'react';

export const useShowWindow = (show: boolean) => {
  useEffect(() => {
    if (show) {
      window.kap.ipc.invoke('kap-window-mount');
    }
  }, [show]);
};
