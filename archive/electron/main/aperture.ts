import {windowManager} from './windows/manager';
import {setRecordingTray, setPausedTray, disableTray, resetTray} from './tray';
import {setCropperShortcutAction} from './global-accelerators';
import {settings} from './common/settings';
import {track} from './common/analytics';
import {getAudioDevices, getSelectedInputDeviceId} from './utils/devices';
import {showError} from './utils/errors';
import {setCurrentRecording, stopCurrentRecording} from './recording-history';
import {Recording} from './video';
import {ApertureOptions, StartRecordingOptions} from './common/types';
import {getCurrentDurationStart, getOverallDuration, setCurrentDurationStart, setOverallDuration} from './utils/track-duration';

const createAperture = require('aperture');
const aperture = createAperture();

let apertureOptions: ApertureOptions;
let recordingName: string | undefined;
let past: number | undefined;

const cleanup = async () => {
  windowManager.cropper?.close();
  resetTray();

  setCropperShortcutAction();
};

export const startRecording = async (options: StartRecordingOptions) => {
  if (past) {
    return;
  }

  past = Date.now();
  recordingName = undefined;

  windowManager.preferences?.close();
  windowManager.cropper?.disable();
  disableTray();

  const {cropperBounds, screenBounds, displayId} = options;

  cropperBounds.y = screenBounds.height - (cropperBounds.y + cropperBounds.height);

  const {
    record60fps,
    showCursor,
    highlightClicks,
    recordAudio
  } = settings.store;

  apertureOptions = {
    fps: record60fps ? 60 : 30,
    cropArea: cropperBounds,
    showCursor,
    highlightClicks,
    screenId: displayId
  };

  if (recordAudio) {
    const audioInputDeviceId = getSelectedInputDeviceId();
    if (audioInputDeviceId) {
      apertureOptions.audioDeviceId = audioInputDeviceId;
    } else {
      const [defaultAudioDevice] = await getAudioDevices();
      apertureOptions.audioDeviceId = defaultAudioDevice?.id;
    }
  }

  console.log(`Collected settings after ${(Date.now() - past) / 1000}s`);

  try {
    const filePath = await aperture.startRecording(apertureOptions);
    setOverallDuration(0);
    setCurrentDurationStart(Date.now());

    setCurrentRecording({
      filePath,
      name: recordingName,
      apertureOptions,
      plugins: {}
    });
  } catch (error) {
    track('recording/stopped/error');
    showError(error as any, {title: 'Recording error', plugin: undefined});
    past = undefined;
    cleanup();
    return;
  }

  const startTime = (Date.now() - past) / 1000;
  if (startTime > 3) {
    track(`recording/started/${startTime}`);
  } else {
    track('recording/started');
  }

  console.log(`Started recording after ${startTime}s`);
  windowManager.cropper?.setRecording();
  setRecordingTray();
  setCropperShortcutAction(stopRecording);
  past = Date.now();

  aperture.recorder.catch((error: any) => {
    if (past) {
      track('recording/stopped/error');
      showError(error, {title: 'Recording error', plugin: undefined});
      past = undefined;
      cleanup();
    }
  });
};

export const stopRecording = async () => {
  if (!past) {
    return;
  }

  console.log(`Stopped recording after ${(Date.now() - past) / 1000}s`);
  past = undefined;

  let filePath;

  try {
    filePath = await aperture.stopRecording();
    setOverallDuration(0);
    setCurrentDurationStart(0);
  } catch (error) {
    track('recording/stopped/error');
    showError(error as any, {title: 'Recording error', plugin: undefined});
    cleanup();
    return;
  }

  try {
    cleanup();
  } finally {
    track('editor/opened/recording');

    const recording = new Recording({
      filePath,
      title: recordingName,
      apertureOptions
    });
    await recording.openEditorWindow();

    stopCurrentRecording(recordingName);
  }
};

export const stopRecordingWithNoEdit = async () => {
  if (!past) {
    return;
  }

  console.log(`Stopped recording after ${(Date.now() - past) / 1000}s`);
  past = undefined;

  try {
    await aperture.stopRecording();
    setOverallDuration(0);
    setCurrentDurationStart(0);
  } catch (error) {
    track('recording/quit/error');
    showError(error as any, {title: 'Recording error', plugin: undefined});
    cleanup();
    return;
  }

  try {
    cleanup();
  } finally {
    track('recording/quit');
    stopCurrentRecording(recordingName);
  }
};

export const pauseRecording = async () => {
  const isPaused = await aperture.isPaused();
  if (!past || isPaused) {
    return;
  }

  try {
    await aperture.pause();
    setOverallDuration(getOverallDuration() + (Date.now() - getCurrentDurationStart()));
    setCurrentDurationStart(0);
    setPausedTray();
    track('recording/paused');
    console.log(`Paused recording after ${(Date.now() - past) / 1000}s`);
  } catch (error) {
    track('recording/paused/error');
    showError(error as any, {title: 'Recording error', plugin: undefined});
    cleanup();
  }
};

export const resumeRecording = async () => {
  const isPaused = await aperture.isPaused();
  if (!past || !isPaused) {
    return;
  }

  try {
    await aperture.resume();
    setCurrentDurationStart(Date.now());
    setRecordingTray();
    track('recording/resumed');
    console.log(`Resume recording after ${(Date.now() - past) / 1000}s`);
  } catch (error) {
    track('recording/resumed/error');
    showError(error as any, {title: 'Recording error', plugin: undefined});
    cleanup();
  }
};
