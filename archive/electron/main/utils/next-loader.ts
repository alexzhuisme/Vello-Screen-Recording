import {app} from 'electron';
import http from 'http';

const waitForDevServer = async (port: number, maxRetries = 60): Promise<void> =>
  new Promise((resolve, reject) => {
    let retries = 0;
    const check = () => {
      const request = http.get(`http://localhost:${port}`, () => {
        resolve();
      });
      request.on('error', () => {
        if (++retries >= maxRetries) {
          reject(new Error(`Dev server at port ${port} did not start within ${maxRetries} seconds`));
          return;
        }

        setTimeout(check, 1000);
      });
    };

    check();
  });

export const prepareRenderer = async (rendererDir: string, port = 8000): Promise<void> => {
  if (app.isPackaged) {
    return;
  }

  const {default: execa} = await import('execa') as any;
  const nodeOptions = [process.env.NODE_OPTIONS, '--openssl-legacy-provider'].filter(Boolean).join(' ');
  const child = execa('npx', ['next', 'dev', '-p', String(port)], {
    cwd: rendererDir,
    stdio: 'pipe',
    env: {
      ...process.env,
      NODE_ENV: 'development',
      NODE_OPTIONS: nodeOptions
    }
  });

  child.stdout?.on('data', (data: Buffer) => {
    console.log(`[next] ${data.toString().trim()}`);
  });

  child.stderr?.on('data', (data: Buffer) => {
    console.error(`[next] ${data.toString().trim()}`);
  });

  app.on('before-quit', () => {
    child.kill();
  });

  await waitForDevServer(port);
};

export const isDevelopment = (): boolean => !app.isPackaged;
