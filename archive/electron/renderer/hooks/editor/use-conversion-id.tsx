import {CreateExportOptions} from 'common/types';
import {createContext, PropsWithChildren, useContext, useMemo, useState} from 'react';

const ConversionIdContext = createContext<{
  conversionId: string;
  setConversionId: (id: string) => void;
  startConversion: (options: CreateExportOptions) => Promise<void>;
}>(undefined);

let savedConversionId: string;

export const ConversionIdContextProvider = (props: PropsWithChildren<Record<string, unknown>>) => {
  const [conversionId, setConversionId] = useState<string>();

  const startConversion = async (options: CreateExportOptions) => {
    const id = await window.kap.ipc.invoke('create-export', options) as string;
    setConversionId(id);
  };

  const updateConversionId = (id: string) => {
    savedConversionId = savedConversionId || id;
    setConversionId(id || savedConversionId);
  };

  const value = useMemo(() => ({
    conversionId,
    setConversionId: updateConversionId,
    startConversion
  }), [conversionId, setConversionId]);

  return (
    <ConversionIdContext.Provider value={value}>
      {props.children}
    </ConversionIdContext.Provider>
  );
};

const useConversionIdContext = () => useContext(ConversionIdContext);

export default useConversionIdContext;
