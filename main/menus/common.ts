import {app} from 'electron';
import {openNewGitHubIssue} from 'electron-util';
import macosRelease from '../utils/macos-release';
import {MenuItemId} from './utils';
import {windowManager} from '../windows/manager';

export const getPreferencesMenuItem = () => ({
  id: MenuItemId.preferences,
  label: 'Preferences…',
  accelerator: 'Command+,',
  click: () => windowManager.preferences?.open()
});

export const getAboutMenuItem = () => ({
  id: MenuItemId.about,
  label: `About ${app.name}`,
  click: () => {
    windowManager.cropper?.close();
    app.focus();
    app.showAboutPanel();
  }
});

export const getSendFeedbackMenuItem = () => ({
  id: MenuItemId.sendFeedback,
  label: 'Send Feedback…',
  click() {
    openNewGitHubIssue({
      user: 'wulkano',
      repo: 'kap',
      body: issueBody
    });
  }
});

const release = macosRelease();

const issueBody = `
<!--
Thank you for helping us test Vello. Your feedback helps us make Vello better for everyone!

Before you continue; please make sure you've searched our existing issues to avoid duplicates. When you're ready to open a new issue, include as much information as possible. You can use the handy template below for bug reports.

Step to reproduce:    If applicable, provide steps to reproduce the issue you're having.
Current behavior:     A description of how Vello is currently behaving.
Expected behavior:    How you expected Vello to behave.
Workaround:           A workaround for the issue if you've found on. (this will help others experiencing the same issue!)
-->

**macOS version:**    ${release.name} (${release.version})
**Vello version:**    ${app.getVersion()}

#### Steps to reproduce

#### Current behavior

#### Expected behavior

#### Workaround

<!-- If you have additional information, enter it below. -->
`;

