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
  stylePreset: number;
}

const START_WITHOUT_TIPS_FLAG: number = wantConstant.Flags.FLAG_START_WITHOUT_TIPS;
const COMMAND_OPEN_ENTRY: string = 'open-entry';
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
      installed: true,
      stylePreset: 0
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
      installed: true,
      stylePreset: 1
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
      installed: true,
      stylePreset: 2
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
      installed: true,
      stylePreset: 0
    },
    {
      id: 'app-album',
      label: '相册',
      bundleName: 'com.zerows.appalbum',
      moduleName: 'entry',
      abilityName: 'EntryAbility',
      icon: $r('app.media.ic_app_album'),
      iconBgColor: '#E0E7FF',
      iconStrokeColor: '#6366F1',
      installed: true,
      stylePreset: 2
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
        iconBgColor: updates.iconBgColor !== undefined ? updates.iconBgColor : item.iconBgColor,
        iconStrokeColor: updates.iconStrokeColor !== undefined ? updates.iconStrokeColor : item.iconStrokeColor,
        installed: updates.installed !== undefined ? updates.installed : item.installed,
        stylePreset: updates.stylePreset !== undefined ? updates.stylePreset : item.stylePreset
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

  private async checkInstalledWithRetry(bundleName: string): Promise<boolean> {
    const first = await this.isBundleInstalled(bundleName);
    if (first) {
      return true;
    }
    await new Promise<void>((resolve) => {
      setTimeout(() => {
        resolve();
      }, 300);
    });
    return this.isBundleInstalled(bundleName);
  }

  private async refreshInstalledState(): Promise<void> {
    if (this.isRefreshing) {
      return;
    }
    this.isRefreshing = true;
    try {
      for (let index = 0; index < this.apps.length; index += 1) {
        const current = this.apps[index];
        const installed = await this.checkInstalledWithRetry(current.bundleName);
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

  private async playLaunchSound(): Promise<void> {
    await this.soundEffectPlayer.play(this.getAbilityContext(), LAUNCH_SOUND_FILE);
  }

  private async openManagedApp(target: ManagedApp): Promise<void> {
    try {
      await this.getAbilityContext().startAbility(this.buildEntryWant(target));
    } catch (err) {
      console.error('Open app failed: ' + JSON.stringify(err));
    }
  }

  private async handleAppClick(target: ManagedApp): Promise<void> {
    if (!target.installed) {
      return;
    }
    await this.playLaunchSound();
    await this.openManagedApp(target);
  }

  private cycleStyle(app: ManagedApp): void {
    const nextPreset: number = (app.stylePreset + 1) % 3;
    if (nextPreset === 0) {
      this.updateApp(app.id, { stylePreset: nextPreset, iconBgColor: '#DBEAFE', iconStrokeColor: '#2563EB' });
      return;
    }
    if (nextPreset === 1) {
      this.updateApp(app.id, { stylePreset: nextPreset, iconBgColor: '#FCE7F3', iconStrokeColor: '#DB2777' });
      return;
    }
    this.updateApp(app.id, { stylePreset: nextPreset, iconBgColor: '#D1FAE5', iconStrokeColor: '#059669' });
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
    .borderRadius(4)
    .backgroundColor(target.iconBgColor)
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
                    .borderRadius(2)
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
            this.buildAppIcon(app, 48, 28)

            Column({ space: 2 }) {
              Text(app.label)
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor('#111827')
              Text(app.installed ? '已安装' : '未安装')
                .fontSize(12)
                .fontColor(app.installed ? '#667085' : '#9CA3AF')
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Text('换风格')
              .fontSize(12)
              .fontColor('#2563EB')
              .padding({ left: 12, right: 12, top: 5, bottom: 5 })
              .borderRadius(4)
              .backgroundColor('#DBEAFE')
              .onClick(() => {
                this.cycleStyle(app);
              })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 12, bottom: 12 })
        }
        .width('100%')
        .backgroundColor('#FFFFFF')
        .borderRadius(4)
        .margin({ left: 16, right: 16, top: 4, bottom: 4 })
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
          .borderRadius(4)
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
          .borderRadius(4)
          .backgroundColor(this.activeTab === 'settings' ? '#DBEAFE' : 'transparent')
          .onClick(() => {
            this.activeTab = 'settings';
          })
        }
      }
      .width('100%')
      .padding({ left: 20, right: 16, top: 14, bottom: 16 })

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
