import UIAbility from '@ohos.app.ability.UIAbility';
import AbilityConstant from '@ohos.app.ability.AbilityConstant';
import Want from '@ohos.app.ability.Want';
import shortcutManager from '@ohos.bundle.shortcutManager';
import window from '@ohos.window';
import { reminderStore } from '../services/ReminderStore';
import { voiceService } from '../services/VoiceService';
import { cameraOcrService } from '../services/CameraOcrService';
import { strongReminderService } from '../services/StrongReminderService';
import { MedicineDatabase } from '../services/MedicineDatabase';
// 云端同步服务预留接口（当前版本不启用）
// import { MedicineSyncService } from '../services/MedicineSyncService';

const SHORTCUT_ID: string = 'desktop-entry';
const COMMAND_SET_SHORTCUT_VISIBLE: string = 'set-shortcut-visible';
const COMMAND_OPEN_ENTRY: string = 'open-entry';
// FLAG_ABILITY_CLEAR_TOP: 清除目标 Ability 之上的所有 Ability
const FLAG_ABILITY_CLEAR_TOP: number = 0x04000000;
// FLAG_ABILITY_NEW_TASK: 在新任务中启动
const FLAG_ABILITY_NEW_TASK: number = 0x10000000;

export default class EntryAbility extends UIAbility {
  private shouldSkipInitialPage: boolean = false;
  private windowStage: window.WindowStage | null = null;

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
    this.windowStage = windowStage;

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
      // 初始化药品库（从 rawfile 加载外部数据源）
      await MedicineDatabase.initialize(this.context);
      console.info('app-medication MedicineDatabase initialized');

      // 云端同步服务预留接口（当前版本不启用）
      // const syncService = MedicineSyncService.getInstance();
      // await syncService.init(this.context);
      // syncService.checkUpdate()...

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
    this.windowStage = null;
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam) {
    console.info('app-medication EntryAbility onNewWant: ' + JSON.stringify(want?.parameters ?? {}));

    // 检查是否是快捷方式命令
    const command: string = String(want?.parameters?.command ?? '');
    if (command === COMMAND_SET_SHORTCUT_VISIBLE) {
      this.shouldSkipInitialPage = true;
      void this.handleShortcutCommand(want);
      return;
    }

    // 外部启动（桌面图标、应用中心等），重新加载主页面
    // 检查启动来源：如果没有 starter 参数，说明是外部启动
    const starter = String(want?.parameters?.starter ?? '');
    const scene = String(want?.parameters?.scene ?? '');

    console.info('app-medication onNewWant: starter=' + starter + ', scene=' + scene);

    // 如果不是从应用内部跳转过来的，重新加载主页面
    if (starter === '' || starter === 'launcher' || starter === 'app-center') {
      console.info('app-medication External launch, reloading main page');
      this.reloadMainPage();
    }
  }

  /**
   * 重新加载主页面（清除之前的页面栈）
   */
  private reloadMainPage(): void {
    if (this.windowStage) {
      this.windowStage.loadContent('pages/Index', (err, data) => {
        if (err.code) {
          console.error('Failed to reload main page: ' + JSON.stringify(err));
          return;
        }
        console.info('Main page reloaded successfully');
      });
    }
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