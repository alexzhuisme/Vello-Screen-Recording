import React from 'react';
import * as Sentry from '@sentry/browser';

const SENTRY_PUBLIC_DSN = 'https://2dffdbd619f34418817f4db3309299ce@sentry.io/255536';

type SentryBoundaryState = {error?: Error};

class SentryErrorBoundary extends React.Component<{children: React.ReactNode}, SentryBoundaryState> {
  state: SentryBoundaryState = {};

  static getDerivedStateFromError(error: Error): SentryBoundaryState {
    return {error};
  }

  async componentDidMount() {
    const isDev = await window.kap.ipc.invoke('kap:app:isDevelopment');
    const allowAnalytics = await window.kap.ipc.invoke('settings:get', 'allowAnalytics');

    if (!isDev && allowAnalytics) {
      const name = await window.kap.app.getName();
      const version = await window.kap.app.getVersion();
      const release = `${name}@${version}`.toLowerCase();
      Sentry.init({dsn: SENTRY_PUBLIC_DSN, release});
    }
  }

  componentDidCatch(error, errorInfo) {
    console.log(error, errorInfo);
    Sentry.configureScope(scope => {
      for (const [key, value] of Object.entries(errorInfo)) {
        scope.setExtra(key, value);
      }
    });

    Sentry.captureException(error);
  }

  render() {
    if (this.state.error) {
      return (
        <div
          style={{
            padding: 24,
            color: 'var(--title-color, #000)',
            fontFamily: '-apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif',
            fontSize: 14
          }}
        >
          Something went wrong while loading this window. You can try again or report the issue if it
          persists.
        </div>
      );
    }

    return this.props.children;
  }
}

export default SentryErrorBoundary;
