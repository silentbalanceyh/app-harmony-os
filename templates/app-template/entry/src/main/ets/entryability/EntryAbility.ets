import UIAbility from '@ohos.app.ability.UIAbility';
import AbilityConstant from '@ohos.app.ability.AbilityConstant';
import Want from '@ohos.app.ability.Want';
import shortcutManager from '@ohos.bundle.shortcutManager';
import window from '@ohos.window';

const APP_TAG: string = '_APP_NAME_';
const SHORTCUT_ID: string = 'desktop-entry';
const COMMAND_SET_SHORTCUT_VISIBLE: string = 'set-shortcut-visible';

export default class EntryAbility extends UIAbility {
  private shouldSkipInitialPage: boolean = false;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam) {
    console.info(APP_TAG + ' EntryAbility onCreate: ' + JSON.stringify(want?.parameters ?? {}));
    this.consumeCommand(want);
  }

  onDestroy() {
    console.info(APP_TAG + ' EntryAbility onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage) {
    console.info(APP_TAG + ' EntryAbility onWindowStageCreate');
    if (this.shouldSkipInitialPage) {
      console.info(APP_TAG + ' EntryAbility skip page load for command dispatch');
      return;
    }
    windowStage.loadContent('pages/Index', (err, data) => {
      if (err.code) {
        console.error('Failed to load ' + APP_TAG + ' content. Cause: ' + JSON.stringify(err));
        return;
      }
      console.info('Succeeded in loading ' + APP_TAG + ' content. Data: ' + JSON.stringify(data));
    });
  }

  onWindowStageDestroy() {
    console.info(APP_TAG + ' EntryAbility onWindowStageDestroy');
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam) {
    console.info(APP_TAG + ' EntryAbility onNewWant: ' + JSON.stringify(want?.parameters ?? {}));
    this.consumeCommand(want);
  }

  onForeground() {
    console.info(APP_TAG + ' EntryAbility onForeground');
  }

  onBackground() {
    console.info(APP_TAG + ' EntryAbility onBackground');
  }

  private consumeCommand(want: Want): void {
    const command: string = String(want?.parameters?.command ?? '');
    if (command !== COMMAND_SET_SHORTCUT_VISIBLE) {
      return;
    }

    this.shouldSkipInitialPage = true;
    void this.handleShortcutCommand(want);
  }

  private async handleShortcutCommand(want: Want): Promise<void> {
    try {
      await shortcutManager.setShortcutVisibleForSelf(
        SHORTCUT_ID,
        String(want.parameters?.desktopVisible ?? 'false') === 'true'
      );

      if (String(want.parameters?.returnToSource ?? 'false') === 'true') {
        await this.context.startAbility({
          bundleName: String(want.parameters?.sourceBundleName ?? ''),
          moduleName: String(want.parameters?.sourceModuleName ?? 'entry'),
          abilityName: String(want.parameters?.sourceAbilityName ?? 'EntryAbility'),
          parameters: {
            command: 'open-entry',
            coordinationScene: 'shortcut-visibility-updated',
            sourceLabel: '_LABEL_',
            startedAt: Date.now()
          }
        });
      }
    } catch (err) {
      console.error(APP_TAG + ' shortcut command failed: ' + JSON.stringify(err));
    } finally {
      try {
        await this.context.terminateSelf();
      } catch (err) {
        console.error(APP_TAG + ' terminate failed: ' + JSON.stringify(err));
      }
    }
  }
}
