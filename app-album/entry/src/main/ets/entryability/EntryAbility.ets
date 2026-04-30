import UIAbility from '@ohos.app.ability.UIAbility';
import AbilityConstant from '@ohos.app.ability.AbilityConstant';
import Want from '@ohos.app.ability.Want';
import shortcutManager from '@ohos.bundle.shortcutManager';
import window from '@ohos.window';
import dataPreferences from '@ohos.data.preferences';
import { settingsStore } from '../utils/SettingsStore';
import { ensureAlbumFontRegistered } from '../utils/AlbumFont';
import { fileRepo } from '../utils/FileRepoUtil';

const SHORTCUT_ID: string = 'desktop-entry';
const COMMAND_SET_SHORTCUT_VISIBLE: string = 'set-shortcut-visible';
const PREFS_NAME = 'album_security';
const KEY_PASSWORD_SET = 'password_set';
const KEY_LAST_ACTIVITY = 'last_activity_time';
const KEY_LOCKED_PAGE = 'locked_page';

export default class EntryAbility extends UIAbility {
  private shouldSkipInitialPage: boolean = false;
  private initialPage: string = 'pages/PasswordSetup';
  private windowStage: window.WindowStage | null = null;
  private idleCheckInterval: number = -1;

  async onCreate(want: Want, launchParam: AbilityConstant.LaunchParam) {
    console.info('app-album EntryAbility onCreate: ' + JSON.stringify(want?.parameters ?? {}));
    fileRepo.init(this.context);
    this.consumeCommand(want);
  }

  private async determineInitialPage(): Promise<void> {
    try {
      const prefs = await dataPreferences.getPreferences(this.context, PREFS_NAME);
      const hasPassword = await prefs.get(KEY_PASSWORD_SET, false) as boolean;
      this.initialPage = hasPassword ? 'pages/PasswordVerify' : 'pages/PasswordSetup';
    } catch (err) {
      console.error('Failed to check password state: ' + JSON.stringify(err));
      this.initialPage = 'pages/PasswordSetup';
    }
  }

  onDestroy() {
    console.info('app-album EntryAbility onDestroy');
    this.stopIdleCheck();
  }

  onWindowStageCreate(windowStage: window.WindowStage) {
    console.info('app-album EntryAbility onWindowStageCreate');
    this.windowStage = windowStage;
    if (this.shouldSkipInitialPage) {
      console.info('app-album EntryAbility skip page load for command dispatch');
      return;
    }
    void this.prepareWindow(windowStage);
  }

  onWindowStageDestroy() {
    console.info('app-album EntryAbility onWindowStageDestroy');
    this.windowStage = null;
    this.stopIdleCheck();
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam) {
    console.info('app-album EntryAbility onNewWant: ' + JSON.stringify(want?.parameters ?? {}));
    this.consumeCommand(want);
    if (this.shouldSkipInitialPage) {
      return;
    }
    void this.loadInitialContent();
  }

  async onForeground() {
    console.info('app-album EntryAbility onForeground');
    await this.checkAutoLock();
    this.startActivityTracking();
    this.startIdleCheck();
  }

  async onBackground() {
    console.info('app-album EntryAbility onBackground');
    await this.recordBackgroundTime();
    this.stopIdleCheck();
  }

  private async recordBackgroundTime(): Promise<void> {
    try {
      await settingsStore.init(this.context);
      const autoLock = await settingsStore.getAutoLock();
      if (autoLock) {
        const prefs = await dataPreferences.getPreferences(this.context, PREFS_NAME);
        await prefs.put('background_time', Date.now());
        await prefs.flush();
      }
    } catch (err) {
      console.error('Record background time failed: ' + JSON.stringify(err));
    }
  }

  private async checkAutoLock(): Promise<void> {
    try {
      await settingsStore.init(this.context);
      const autoLock = await settingsStore.getAutoLock();
      if (!autoLock) {
        return;
      }
      const prefs = await dataPreferences.getPreferences(this.context, PREFS_NAME);
      const bgTime = await prefs.get('background_time', 0) as number;
      if (bgTime === 0) {
        return;
      }
      const lockDelayMinutes = await settingsStore.getLockDelay();
      const elapsed = Date.now() - bgTime;
      if (elapsed > lockDelayMinutes * 60 * 1000) {
        await prefs.put('background_time', 0);
        await prefs.put('return_after_unlock', true);
        await prefs.flush();
        if (this.windowStage) {
          this.windowStage.loadContent('pages/PasswordVerify', (err) => {
            if (err.code) {
              console.error('Auto-lock load content failed: ' + JSON.stringify(err));
            }
          });
        }
      }
    } catch (err) {
      console.error('Check auto lock failed: ' + JSON.stringify(err));
    }
  }

  // Activity tracking for idle lock
  private startActivityTracking(): void {
    // Activity is recorded by pages calling recordActivity()
  }

  static async recordActivity(context: Context): Promise<void> {
    try {
      const prefs = await dataPreferences.getPreferences(context, PREFS_NAME);
      await prefs.put(KEY_LAST_ACTIVITY, Date.now());
      await prefs.flush();
    } catch {
      // silent
    }
  }

  private startIdleCheck(): void {
    this.stopIdleCheck();
    this.idleCheckInterval = setInterval(() => {
      void this.checkIdleLock();
    }, 30000) as number; // check every 30s
  }

  private stopIdleCheck(): void {
    if (this.idleCheckInterval !== -1) {
      clearInterval(this.idleCheckInterval);
      this.idleCheckInterval = -1;
    }
  }

  private async checkIdleLock(): Promise<void> {
    try {
      await settingsStore.init(this.context);
      const autoLock = await settingsStore.getAutoLock();
      if (!autoLock) return;

      const prefs = await dataPreferences.getPreferences(this.context, PREFS_NAME);
      const lastActivity = await prefs.get(KEY_LAST_ACTIVITY, 0) as number;
      if (lastActivity === 0) return;

      const lockDelayMinutes = await settingsStore.getLockDelay();
      const idleTime = Date.now() - lastActivity;
      if (idleTime > lockDelayMinutes * 60 * 1000) {
        await prefs.put('return_after_unlock', true);
        await prefs.put(KEY_LAST_ACTIVITY, 0);
        await prefs.flush();
        this.stopIdleCheck();
        if (this.windowStage) {
          this.windowStage.loadContent('pages/PasswordVerify', (err) => {
            if (err.code) {
              console.error('Idle-lock load content failed: ' + JSON.stringify(err));
            }
          });
        }
      }
    } catch (err) {
      console.error('Idle lock check failed:', JSON.stringify(err));
    }
  }

  private async loadInitialContent(): Promise<void> {
    if (!this.windowStage) {
      console.error('app-album WindowStage is unavailable when loading initial content');
      return;
    }

    await this.determineInitialPage();
    this.windowStage.loadContent(this.initialPage, (err, data) => {
      if (err.code) {
        console.error('Failed to load app-album content. Cause: ' + JSON.stringify(err));
        return;
      }
      console.info('Succeeded in loading app-album content. Data: ' + JSON.stringify(data));
    });
  }

  private async prepareWindow(windowStage: window.WindowStage): Promise<void> {
    try {
      await ensureAlbumFontRegistered(this.context);
    } catch (err) {
      console.error('Failed to prepare album font: ' + JSON.stringify(err));
    }
    await this.loadInitialContent();
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
            sourceLabel: '加密相册',
            startedAt: Date.now()
          }
        });
      }
    } catch (err) {
      console.error('app-album shortcut command failed: ' + JSON.stringify(err));
    } finally {
      try {
        await this.context.terminateSelf();
      } catch (err) {
        console.error('app-album terminate failed: ' + JSON.stringify(err));
      }
    }
  }
}
