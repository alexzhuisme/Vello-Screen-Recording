import {createContext, useContext, useState, useEffect, ReactNode} from 'react';

const WindowStateContext = createContext<any>(undefined);

export const WindowStateProvider = (props: {children: ReactNode}) => {
  const [windowState, setWindowState] = useState();

  useEffect(() => {
    window.kap.ipc.invoke('kap-window-state').then(setWindowState);

    return window.kap.ipc.on('kap-window-state', (newState: any) => {
      setWindowState(newState);
    });
  }, []);

  return (
    <WindowStateContext.Provider value={windowState}>
      {props.children}
    </WindowStateContext.Provider>
  );
};

// Should not be used directly
// Each page should export its own typed hook
// eslint-disable-next-line @typescript-eslint/comma-dangle
const useWindowState = <T,>() => useContext<T>(WindowStateContext);

export default useWindowState;
