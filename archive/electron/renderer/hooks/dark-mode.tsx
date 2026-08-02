import {useState, useEffect} from 'react';

const useDarkMode = () => {
  const [isDarkMode, setIsDarkMode] = useState(false);

  useEffect(() => {
    window.kap.system.isDarkMode().then(setIsDarkMode);

    return window.kap.system.onThemeChanged((isDark: boolean) => {
      setIsDarkMode(isDark);
    });
  }, []);

  return isDarkMode;
};

export default useDarkMode;
