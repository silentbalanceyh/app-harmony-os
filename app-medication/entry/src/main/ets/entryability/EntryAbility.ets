import UIAbility from '@ohos.app.ability.UIAbility';
import AbilityConstant from '@ohos.app.ability.AbilityConstant';
import Want from '@ohos.app.ability.Want';
import shortcutManager from '@ohos.bundle.shortcutManager';
import window from '@ohos.window';
import { reminderStore } from '../services/ReminderStore';
import { voiceService } from '../services/VoiceService';
import { cameraOcrService } from '../services/CameraOcrService';
import { strongReminderService } from '../services/StrongReminderService';

const SHORTCUT_ID: string = 'desktop-entry';
const COMMAND_SET_SHORTCUT_VISIBLE: string = 'set-shortcut-visible';

export default class EntryAbility extends UIAbility {
  private shouldSkipInitialPage: boolean = false;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam) {
    console.info('app-medication EntryAbility onCreate: ' + JSON.stringify(want?.parameters ?? {}));
    this.consumeCommand(want);
  }

  onDestroy() {
    console.info('app-medication EntryAbility onDestroy');
    void voiceService.destroy();
    void cameraOcrService.destroy();
    void strongReminderService.destroy();
  }

  onWindowStageCreate(windowStage: window.WindowStage) {
    console.info('app-medication EntryAbility onWindowStageCreate');
    if (this.shouldSkipInitialPage) {
      console.info('app-medication skip page load for command dispatch');
      return;
    }

    void this.initServices();

    windowStage.loadContent('pages/Index', (err, data) => {
      if (err.code) {
        console.error('Failed to load content: ' + JSON.stringify(err));
        return;
      }
      console.info('Succeeded in loading content: ' + JSON.stringify(data));
    });
  }

  private async initServices(): Promise<void> {
    try {
      await reminderStore.init(this.context);
      console.info('app-medication ReminderStore initialized');

      await cameraOcrService.init(this.context);
      console.info('app-medication CameraOcrService initialized');

      await strongReminderService.init(this.context, reminderStore);
      console.info('app-medication StrongReminderService initialized');

      console.info('app-medication All services initialized');
    } catch (err) {
      console.error('app-medication Init services failed: ' + JSON.stringify(err));
    }
  }

  onWindowStageDestroy() {
    console.info('app-medication EntryAbility onWindowStageDestroy');
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam) {
    console.info('app-medication EntryAbility onNewWant: ' + JSON.stringify(want?.parameters ?? {}));
    this.consumeCommand(want);
  }

  onForeground() {
    console.info('app-medication EntryAbility onForeground');
  }

  onBackground() {
    console.info('app-medication EntryAbility onBackground');
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
            sourceLabel: '用药提醒',
            startedAt: Date.now()
          }
        });
      }
    } catch (err) {
      console.error('app-medication shortcut command failed: ' + JSON.stringify(err));
    } finally {
      try {
        await this.context.terminateSelf();
      } catch (err) {
        console.error('app-medication terminate failed: ' + JSON.stringify(err));
      }
    }
  }
}