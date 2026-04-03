import common from '@ohos.app.ability.common';
import Want from '@ohos.app.ability.Want';
import wantConstant from '@ohos.app.ability.wantConstant';
import Package from '@system.package';
import SoundEffectPlayer from '../utils/SoundEffectPlayer';

interface ManagedApp {
  id: string;
  label: string;
  bundleName: string;
  moduleName: string;
  abilityName: string;
  icon: Resource;
  iconBgColor: string;
  iconStrokeColor: string;
  installed: boolean;
  canUninstall: boolean;
  showOnDesktop: boolean;
  supportsInstallOnDemand: boolean;
}

const INSTALL_ON_DEMAND_FLAG: number = wantConstant.Flags.FLAG_INSTALL_ON_DEMAND;
const START_WITHOUT_TIPS_FLAG: number = wantConstant.Flags.FLAG_START_WITHOUT_TIPS;
const COMMAND_OPEN_ENTRY: string = 'open-entry';
const COMMAND_SET_SHORTCUT_VISIBLE: string = 'set-shortcut-visible';
const LAUNCH_SOUND_FILE: string = 'launch.wav';

@Entry
@Component
struct Index {
  @State private activeTab: string = 'entry';
  @State private apps: ManagedApp[] = [
    {
      id: 'app-monitor',
      label: '监控中心',
      bundleName: 'com.zerows.appmonitor',
      moduleName: 'entry',
      abilityName: 'EntryAbility',
      icon: $r('app.media.ic_app_monitor'),
      iconBgColor: '#DBEAFE',
      iconStrokeColor: '#2563EB',
      installed: false,
      canUninstall: true,
      showOnDesktop: false,
      supportsInstallOnDemand: true
    },
    {
      id: 'app-security',
      label: '安全中心',
      bundleName: 'com.zerows.appsecurity',
      moduleName: 'entry',
      abilityName: 'EntryAbility',
      icon: $r('app.media.ic_app_security'),
      iconBgColor: '#FEF3C7',
      iconStrokeColor: '#D97706',
      installed: false,
      canUninstall: true,
      showOnDesktop: true,
      supportsInstallOnDemand: true
    },
    {
      id: 'app-hello',
      label: 'Hello 应用',
      bundleName: 'com.zerows.apphello',
      moduleName: 'entry',
      abilityName: 'EntryAbility',
      icon: $r('app.media.ic_app_hello'),
      iconBgColor: '#FCE7F3',
      iconStrokeColor: '#DB2777',
      installed: false,
      canUninstall: true,
      showOnDesktop: false,
      supportsInstallOnDemand: true
    },
    {
      id: 'app-medication',
      label: '用药提醒',
      bundleName: 'com.zerows.appmedication',
      moduleName: 'entry',
      abilityName: 'EntryAbility',
      icon: $r('app.media.ic_app_medication'),
      iconBgColor: '#D1FAE5',
      iconStrokeColor: '#059669',
      installed: false,
      canUninstall: true,
      showOnDesktop: false,
      supportsInstallOnDemand: true
    }
  ];
  @State private isRefreshing: boolean = false;

  private readonly soundEffectPlayer: SoundEffectPlayer = new SoundEffectPlayer();

  aboutToAppear(): void {
    void this.refreshInstalledState();
  }

  private getAbilityContext(): common.UIAbilityContext {
    const hostContext = this.getUIContext().getHostContext();
    if (!hostContext) {
      throw new Error('UIAbilityContext is unavailable');
    }
    return hostContext as common.UIAbilityContext;
  }

  private updateApp(appId: string, updates: Partial<ManagedApp>): void {
    this.apps = this.apps.map((item: ManagedApp) => {
      if (item.id !== appId) {
        return item;
      }
      return {
        id: item.id,
        label: item.label,
        bundleName: item.bundleName,
        moduleName: item.moduleName,
        abilityName: item.abilityName,
        icon: item.icon,
        iconBgColor: item.iconBgColor,
        iconStrokeColor: item.iconStrokeColor,
        installed: updates.installed !== undefined ? updates.installed : item.installed,
        canUninstall: item.canUninstall,
        showOnDesktop: updates.showOnDesktop !== undefined ? updates.showOnDesktop : item.showOnDesktop,
        supportsInstallOnDemand: item.supportsInstallOnDemand
      };
    });
  }

  private async isBundleInstalled(bundleName: string): Promise<boolean> {
    return new Promise((resolve) => {
      Package.hasInstalled({
        bundleName,
        success: (data) => {
          resolve(!!data?.result);
        },
        fail: () => {
          resolve(false);
        },
        complete: () => {
        }
      });
    });
  }

  private async refreshInstalledState(): Promise<void> {
    if (this.isRefreshing) {
      return;
    }
    this.isRefreshing = true;
    try {
      for (let index = 0; index < this.apps.length; index += 1) {
        const current = this.apps[index];
        const installed = await this.isBundleInstalled(current.bundleName);
        this.updateApp(current.id, { installed });
      }
    } finally {
      this.isRefreshing = false;
    }
  }

  private buildEntryWant(target: ManagedApp): Want {
    return {
      bundleName: target.bundleName,
      moduleName: target.moduleName,
      abilityName: target.abilityName,
      flags: START_WITHOUT_TIPS_FLAG,
      parameters: {
        command: COMMAND_OPEN_ENTRY,
        starterApp: 'app-center',
        coordinationScene: 'open-app',
        sourceLabel: '应用中心',
        selectedAppId: target.id,
        startedAt: Date.now(),
        sourceBundleName: 'com.zerows.appcenter',
        sourceModuleName: 'entry',
        sourceAbilityName: 'EntryAbility'
      }
    };
  }

  private buildShortcutWant(target: ManagedApp, visible: boolean): Want {
    return {
      bundleName: target.bundleName,
      moduleName: target.moduleName,
      abilityName: target.abilityName,
      flags: START_WITHOUT_TIPS_FLAG,
      parameters: {
        command: COMMAND_SET_SHORTCUT_VISIBLE,
        starterApp: 'app-center',
        coordinationScene: 'toggle-desktop-shortcut',
        sourceLabel: '应用中心',
        selectedAppId: target.id,
        startedAt: Date.now(),
        sourceBundleName: 'com.zerows.appcenter',
        sourceModuleName: 'entry',
        sourceAbilityName: 'EntryAbility',
        desktopVisible: visible ? 'true' : 'false'
      }
    };
  }

  private buildInstallWant(target: ManagedApp): Want {
    return {
      bundleName: target.bundleName,
      moduleName: target.moduleName,
      abilityName: target.abilityName,
      flags: START_WITHOUT_TIPS_FLAG | INSTALL_ON_DEMAND_FLAG,
      parameters: {
        starterApp: 'app-center',
        coordinationScene: 'install-on-demand',
        sourceLabel: '应用中心',
        selectedAppId: target.id,
        startedAt: Date.now()
      }
    };
  }

  private async playLaunchSound(): Promise<void> {
    await this.soundEffectPlayer.play(this.getAbilityContext(), LAUNCH_SOUND_FILE);
  }

  private async openManagedApp(target: ManagedApp): Promise<void> {
    try {
      await this.getAbilityContext().startAbility(this.buildEntryWant(target));
      this.updateApp(target.id, { installed: true });
    } catch (err) {
      console.error('Open app failed: ' + JSON.stringify(err));
    }
  }

  private async installOnDemand(target: ManagedApp): Promise<void> {
    if (!target.supportsInstallOnDemand) {
      return;
    }
    try {
      await this.getAbilityContext().startAbility(this.buildInstallWant(target));
    } catch (err) {
      console.error('Install on demand failed: ' + JSON.stringify(err));
    }
  }

  private async setDesktopVisibility(target: ManagedApp, visible: boolean): Promise<void> {
    try {
      await this.getAbilityContext().startAbility(this.buildShortcutWant(target, visible));
      this.updateApp(target.id, { showOnDesktop: visible });
    } catch (err) {
      console.error('Set desktop shortcut failed: ' + JSON.stringify(err));
    }
  }

  private async handleAppClick(target: ManagedApp): Promise<void> {
    if (target.installed) {
      await this.playLaunchSound();
      await this.openManagedApp(target);
    } else {
      await this.installOnDemand(target);
    }
    await this.refreshInstalledState();
  }

  @Builder
  private buildAppIcon(target: ManagedApp, size: number, iconSize: number) {
    Column() {
      Image(target.icon)
        .width(iconSize)
        .height(iconSize)
        .objectFit(ImageFit.Contain)
    }
    .width(size)
    .height(size)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .borderRadius(size / 5)
    .backgroundColor(target.iconBgColor)
    .border({
      width: 2,
      color: target.iconStrokeColor,
      radius: size / 5
    })
  }

  @Builder
  private buildEntryTab() {
    Column() {
      Grid() {
        ForEach(this.apps, (app: ManagedApp) => {
          GridItem() {
            Column({ space: 6 }) {
              Stack({ alignContent: Alignment.TopEnd }) {
                this.buildAppIcon(app, 64, 42)
                if (!app.installed) {
                  Text('未装')
                    .fontSize(9)
                    .fontColor('#FFFFFF')
                    .fontWeight(FontWeight.Medium)
                    .padding({ left: 5, right: 5, top: 2, bottom: 2 })
                    .borderRadius(999)
                    .backgroundColor('#F59E0B')
                    .translate({ x: 2, y: -2 })
                }
              }

              Text(app.label)
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor('#111827')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .width('100%')
                .textAlign(TextAlign.Center)
            }
            .onClick(() => {
              void this.handleAppClick(app);
            })
          }
        }, (app: ManagedApp) => app.id)
      }
      .columnsTemplate('2fr 2fr 2fr 2fr')
      .columnsGap(8)
      .rowsGap(16)
      .padding({ left: 16, right: 16, top: 16, bottom: 16 })
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private buildSettingTab() {
    List() {
      ForEach(this.apps, (app: ManagedApp) => {
        ListItem() {
          Row({ space: 14 }) {
            this.buildAppIcon(app, 48, 26)

            Column({ space: 2 }) {
              Text(app.label)
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor('#111827')

              Text(app.installed ? '已安装' : '尚未安装')
                .fontSize(12)
                .fontColor(app.installed ? '#667085' : '#9CA3AF')
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            if (!app.installed) {
              Text('安装')
                .fontSize(12)
                .fontColor('#2563EB')
                .padding({ left: 12, right: 12, top: 5, bottom: 5 })
                .borderRadius(999)
                .backgroundColor('#DBEAFE')
                .onClick(() => {
                  void this.installOnDemand(app);
                })
            }
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 12, bottom: 12 })
        }
        .width('100%')
        .backgroundColor('#FFFFFF')
        .borderRadius(16)
        .margin({ left: 16, right: 16, top: 6, bottom: 6 })
      }, (app: ManagedApp) => app.id)
    }
    .width('100%')
    .layoutWeight(1)
    .padding({ top: 8, bottom: 8 })
  }

  build() {
    Column() {
      Row() {
        Text('应用中心')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#111827')

        Blank()

        Row({ space: 4 }) {
          Column() {
            Image(this.activeTab === 'entry' ? $r('app.media.ic_tab_entry_active') : $r('app.media.ic_tab_entry'))
              .width(22)
              .height(22)
              .objectFit(ImageFit.Contain)
            Text('入口')
              .fontSize(10)
              .fontColor(this.activeTab === 'entry' ? '#2563EB' : '#667085')
              .fontWeight(this.activeTab === 'entry' ? FontWeight.Medium : FontWeight.Normal)
          }
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .borderRadius(10)
          .backgroundColor(this.activeTab === 'entry' ? '#DBEAFE' : 'transparent')
          .onClick(() => {
            this.activeTab = 'entry';
          })

          Column() {
            Image(this.activeTab === 'settings' ? $r('app.media.ic_tab_settings_active') : $r('app.media.ic_tab_settings'))
              .width(22)
              .height(22)
              .objectFit(ImageFit.Contain)
            Text('设置')
              .fontSize(10)
              .fontColor(this.activeTab === 'settings' ? '#2563EB' : '#667085')
              .fontWeight(this.activeTab === 'settings' ? FontWeight.Medium : FontWeight.Normal)
          }
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .borderRadius(10)
          .backgroundColor(this.activeTab === 'settings' ? '#DBEAFE' : 'transparent')
          .onClick(() => {
            this.activeTab = 'settings';
          })
        }
      }
      .width('100%')
      .padding({ left: 20, right: 16, top: 14, bottom: 12 })

      Divider()
        .color('#F1F5F9')

      if (this.activeTab === 'entry') {
        this.buildEntryTab()
      } else {
        this.buildSettingTab()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F3F6FC')
  }
}
