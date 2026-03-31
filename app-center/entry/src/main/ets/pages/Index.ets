import common from '@ohos.app.ability.common';
import Want from '@ohos.app.ability.Want';
import wantConstant from '@ohos.app.ability.wantConstant';
import Package from '@system.package';
import SoundEffectPlayer from '../utils/SoundEffectPlayer';

interface ManagedApp {
  id: string;
  label: string;
  shortLabel: string;
  bundleName: string;
  moduleName: string;
  abilityName: string;
  serviceName?: string;
  description: string;
  iconGlyph: string;
  accentColor: string;
  installed: boolean;
  supportsInstallOnDemand: boolean;
  canUninstall: boolean;
  showOnDesktop: boolean;
}

const INSTALL_ON_DEMAND_FLAG: number = wantConstant.Flags.FLAG_INSTALL_ON_DEMAND;
const START_WITHOUT_TIPS_FLAG: number = wantConstant.Flags.FLAG_START_WITHOUT_TIPS;
const ACTION_MANAGE_APPLICATIONS_SETTINGS: string = 'ohos.settings.manage.applications';
const ACTION_APPLICATION_DETAILS_SETTINGS: string = 'ohos.settings.application.details';
const COMMAND_OPEN_ENTRY: string = 'open-entry';
const COMMAND_SET_SHORTCUT_VISIBLE: string = 'set-shortcut-visible';
const LAUNCH_SOUND_FILE: string = 'launch.wav';

@Entry
@Component
struct Index {
  @State private apps: ManagedApp[] = [
    {
      id: 'app-center',
      label: '应用中心',
      shortLabel: 'Center',
      bundleName: 'com.zerows.appcenter',
      moduleName: 'entry',
      abilityName: 'EntryAbility',
      serviceName: 'AppBridgeService',
      description: '作为主入口集中呈现、打开和编排基础应用。',
      iconGlyph: '中',
      accentColor: '#1C65FF',
      installed: true,
      supportsInstallOnDemand: false,
      canUninstall: false,
      showOnDesktop: true
    },
    {
      id: 'app-monitor',
      label: '监控中心',
      shortLabel: 'Monitor',
      bundleName: 'com.zerows.appmonitor',
      moduleName: 'entry',
      abilityName: 'EntryAbility',
      serviceName: 'AppBridgeService',
      description: '负责健康状态、设备指标和运行态观测。',
      iconGlyph: '监',
      accentColor: '#0A8F6A',
      installed: false,
      supportsInstallOnDemand: true,
      canUninstall: true,
      showOnDesktop: false
    },
    {
      id: 'app-security',
      label: '安全中心',
      shortLabel: 'Security',
      bundleName: 'com.zerows.appsecurity',
      moduleName: 'entry',
      abilityName: 'EntryAbility',
      serviceName: 'AppBridgeService',
      description: '负责账号安全、设备校验和风险控制。',
      iconGlyph: '安',
      accentColor: '#E45D2E',
      installed: false,
      supportsInstallOnDemand: true,
      canUninstall: true,
      showOnDesktop: false
    },
    {
      id: 'app-hello',
      label: 'Hello 应用',
      shortLabel: 'Hello',
      bundleName: 'com.zerows.apphello',
      moduleName: 'entry',
      abilityName: 'EntryAbility',
      serviceName: 'AppBridgeService',
      description: '作为首个业务应用，验证与系统应用协同。',
      iconGlyph: 'Hi',
      accentColor: '#7D42E9',
      installed: false,
      supportsInstallOnDemand: true,
      canUninstall: true,
      showOnDesktop: false
    },
    {
      id: 'app-medication',
      label: '用药提醒',
      shortLabel: 'Medication',
      bundleName: 'com.zerows.appmedication',
      moduleName: 'entry',
      abilityName: 'EntryAbility',
      serviceName: 'AppBridgeService',
      description: '面向老年人健康管理，负责按时提醒、服药确认和家属协助提示。',
      iconGlyph: '药',
      accentColor: '#C2410C',
      installed: false,
      supportsInstallOnDemand: true,
      canUninstall: true,
      showOnDesktop: false
    }
  ];
  @State private selectedAppId: string = 'app-center';
  @State private statusTitle: string = '应用中心已准备就绪';
  @State private statusDetail: string = '默认只有应用中心出现在桌面，其余应用通过统一入口进入。';
  @State private isRefreshing: boolean = false;
  private readonly soundEffectPlayer: SoundEffectPlayer = new SoundEffectPlayer();

  private getLaunchHint(target: ManagedApp): string {
    if (target.id === 'app-center') {
      return '当前应用就是统一入口。';
    }
    return '从应用中心进入其他应用时，系统可能要求确认一次；应用内返回应用中心不再重复确认。';
  }

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

  private buildFallbackApp(): ManagedApp {
    return {
      id: 'app-center',
      label: '应用中心',
      shortLabel: 'Center',
      bundleName: 'com.zerows.appcenter',
      moduleName: 'entry',
      abilityName: 'EntryAbility',
      serviceName: 'AppBridgeService',
      description: '作为主入口集中呈现、打开和编排基础应用。',
      iconGlyph: '中',
      accentColor: '#1C65FF',
      installed: true,
      supportsInstallOnDemand: false,
      canUninstall: false,
      showOnDesktop: true
    };
  }

  private cloneApp(item: ManagedApp, installed: boolean = item.installed, showOnDesktop: boolean = item.showOnDesktop): ManagedApp {
    return {
      id: item.id,
      label: item.label,
      shortLabel: item.shortLabel,
      bundleName: item.bundleName,
      moduleName: item.moduleName,
      abilityName: item.abilityName,
      serviceName: item.serviceName,
      description: item.description,
      iconGlyph: item.iconGlyph,
      accentColor: item.accentColor,
      installed,
      supportsInstallOnDemand: item.supportsInstallOnDemand,
      canUninstall: item.canUninstall,
      showOnDesktop
    };
  }

  private safeText(value: string | undefined, fallback: string = ''): string {
    if (value === undefined || value === null) {
      return fallback;
    }
    return value;
  }

  private getAppGlyph(target: ManagedApp): string {
    if (target.iconGlyph) {
      return target.iconGlyph;
    }
    if (target.shortLabel) {
      return target.shortLabel.length > 2 ? target.shortLabel.slice(0, 2) : target.shortLabel;
    }
    if (target.label) {
      return target.label.length > 2 ? target.label.slice(0, 2) : target.label;
    }
    return '应';
  }

  private getSelectedApp(): ManagedApp {
    const current = this.apps.find((item: ManagedApp) => item.id === this.selectedAppId);
    if (current) {
      return current;
    }
    return this.apps[0] ?? this.buildFallbackApp();
  }

  private getInstalledCount(): number {
    let count = 0;
    this.apps.forEach((item: ManagedApp) => {
      if (item.installed) {
        count += 1;
      }
    });
    return count;
  }

  private getPendingCount(): number {
    return this.apps.length - this.getInstalledCount();
  }

  private updateInstalledFlag(appId: string, installed: boolean): void {
    this.apps = this.apps.map((item: ManagedApp) => item.id === appId ? this.cloneApp(item, installed) : item);
  }

  private updateDesktopFlag(appId: string, showOnDesktop: boolean): void {
    this.apps = this.apps.map((item: ManagedApp) => item.id === appId ? this.cloneApp(item, item.installed, showOnDesktop) : item);
  }

  private updateStatus(title: string, detail: string): void {
    this.statusTitle = title;
    this.statusDetail = detail;
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
        this.updateInstalledFlag(current.id, installed);
      }
      this.updateStatus(
        '已安装 ' + this.getInstalledCount() + ' / ' + this.apps.length + ' 个基础应用',
        this.getPendingCount() === 0 ? '所有基础应用都已可用。' : '仍有 ' + this.getPendingCount() + ' 个应用待安装或待恢复。'
      );
    } finally {
      this.isRefreshing = false;
    }
  }

  private supportsDesktopShortcut(target: ManagedApp): boolean {
    return target.id !== 'app-center' && !!target.serviceName;
  }

  private buildEntryWant(target: ManagedApp, command: string, scene: string, desktopVisible?: boolean): Want {
    if (desktopVisible !== undefined) {
      return {
        bundleName: target.bundleName,
        moduleName: target.moduleName,
        abilityName: target.abilityName,
        flags: START_WITHOUT_TIPS_FLAG,
        parameters: {
          command,
          starterApp: 'app-center',
          coordinationScene: scene,
          sourceLabel: '应用中心',
          selectedAppId: target.id,
          startedAt: Date.now(),
          sourceBundleName: 'com.zerows.appcenter',
          sourceModuleName: 'entry',
          sourceAbilityName: 'EntryAbility',
          desktopVisible: desktopVisible ? 'true' : 'false',
          returnToSource: 'true'
        }
      };
    }

    return {
      bundleName: target.bundleName,
      moduleName: target.moduleName,
      abilityName: target.abilityName,
      flags: START_WITHOUT_TIPS_FLAG,
      parameters: {
        command,
        starterApp: 'app-center',
        coordinationScene: scene,
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

  private async openManagedApp(target: ManagedApp): Promise<void> {
    if (target.id === 'app-center') {
      this.updateStatus('当前已在应用中心', '无需重复拉起应用中心。');
      return;
    }

    try {
      await this.getAbilityContext().startAbility(this.buildEntryWant(target, COMMAND_OPEN_ENTRY, 'open-app'));
      this.updateInstalledFlag(target.id, true);
      this.updateStatus('已打开 ' + target.label, '已通过目标应用首页拉起。');
    } catch (err) {
      this.updateStatus('打开 ' + target.label + ' 失败', '请确认该应用已安装，并检查目标首页是否可用。');
      console.error('Open managed app failed: ' + JSON.stringify(err));
    }
  }

  private async installOnDemand(target: ManagedApp): Promise<void> {
    try {
      await this.getAbilityContext().startAbility(this.buildInstallWant(target));
      this.updateStatus('已提交安装请求', target.label + ' 已尝试通过按需安装方式拉起。');
    } catch (err) {
      this.updateStatus('无法直接安装 ' + target.label, '当前设备未提供按需安装能力，请先用脚本安装或从系统入口安装。');
      console.error('Install on demand failed: ' + JSON.stringify(err));
    }
  }

  private async openApplicationManager(): Promise<void> {
    try {
      await this.getAbilityContext().startAbility({
        action: ACTION_MANAGE_APPLICATIONS_SETTINGS
      });
      this.updateStatus('已打开应用管理', '可在系统应用管理页继续安装或卸载应用。');
    } catch (err) {
      this.updateStatus('无法打开应用管理', '当前设备没有可用的系统应用管理入口。');
      console.error('Open manager failed: ' + JSON.stringify(err));
    }
  }

  private async openApplicationDetails(target: ManagedApp): Promise<void> {
    try {
      await this.getAbilityContext().startAbility({
        action: ACTION_APPLICATION_DETAILS_SETTINGS,
        parameters: {
          bundleName: target.bundleName,
          packageName: target.bundleName,
          targetBundleName: target.bundleName
        }
      });
      this.updateStatus('已打开 ' + target.label + ' 管理页', '可在系统详情页执行卸载或权限管理。');
    } catch (err) {
      await this.openApplicationManager();
      console.error('Open detail failed: ' + JSON.stringify(err));
    }
  }

  private async setDesktopVisibility(target: ManagedApp, visible: boolean): Promise<void> {
    if (!this.supportsDesktopShortcut(target)) {
      this.updateStatus(target.label + ' 是系统主入口', '应用中心自身保持桌面主入口，无需额外桌面配置。');
      return;
    }

    if (!target.installed) {
      this.updateStatus(target.label + ' 尚未安装', '请先安装应用，再决定是否在桌面显示。');
      return;
    }

    try {
      await this.getAbilityContext().startAbility(this.buildEntryWant(
        target,
        COMMAND_SET_SHORTCUT_VISIBLE,
        'toggle-desktop-shortcut',
        visible
      ));
      this.updateDesktopFlag(target.id, visible);
      this.updateStatus(
        visible ? '已显示桌面入口' : '已隐藏桌面入口',
        visible ? target.label + ' 已出现在桌面，可直接从桌面进入。' : target.label + ' 已恢复为仅能通过应用中心统一进入。'
      );
    } catch (err) {
      this.updateStatus('桌面入口更新失败', '目标应用未能完成桌面显隐切换。');
      console.error('Toggle desktop shortcut failed: ' + JSON.stringify(err));
    }
  }

  private async handleInstall(target: ManagedApp): Promise<void> {
    if (target.installed) {
      this.updateStatus(target.label + ' 已安装', '可以直接打开，或进入系统详情页继续管理。');
      return;
    }
    await this.installOnDemand(target);
    await this.refreshInstalledState();
  }

  private async handleUninstall(target: ManagedApp): Promise<void> {
    if (!target.canUninstall) {
      this.updateStatus(target.label + ' 不可卸载', '应用中心自身保持常驻，不能从这里移除。');
      return;
    }

    if (!target.installed) {
      this.updateStatus(target.label + ' 当前未安装', '先安装后才需要执行卸载操作。');
      return;
    }

    await this.openApplicationDetails(target);
  }

  private async handleOpen(target: ManagedApp): Promise<void> {
    if (target.installed) {
      await this.playLaunchSound();
    }
    await this.openManagedApp(target);
    await this.refreshInstalledState();
  }

  @Builder
  private buildAppIcon(target: ManagedApp) {
    Column({ space: 8 }) {
      Stack({ alignContent: Alignment.TopEnd }) {
        Column() {
          Text(this.getAppGlyph(target))
            .fontSize(this.getAppGlyph(target).length > 1 ? 24 : 30)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
        }
        .width(70)
        .height(70)
        .justifyContent(FlexAlign.Center)
        .borderRadius(20)
        .backgroundColor(target.accentColor)
        .shadow({
          radius: 20,
          color: Color.Transparent,
          offsetX: 0,
          offsetY: 10
        })

        Row() {
          Text(target.installed ? '已装' : '待装')
            .fontSize(10)
            .fontColor('#FFFFFF')
            .fontWeight(FontWeight.Medium)
        }
        .padding({ left: 8, right: 8, top: 3, bottom: 3 })
        .borderRadius(999)
        .backgroundColor(target.installed ? '#147D64' : '#C05621')
        .translate({ x: 6, y: -6 })
      }

      Text(this.safeText(target.label, target.id))
        .fontSize(13)
        .fontWeight(target.id === this.selectedAppId ? FontWeight.Bold : FontWeight.Medium)
        .fontColor('#122033')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(target.showOnDesktop ? '桌面可见' : '仅中心入口')
        .fontSize(11)
        .fontColor(target.showOnDesktop ? '#1D4ED8' : '#607087')
    }
    .width('100%')
    .padding({ top: 8, bottom: 6 })
    .onClick(() => {
      this.selectedAppId = target.id;
      this.updateStatus('已选中 ' + target.label, target.description);
    })
  }

  build() {
    Scroll() {
      Column({ space: 22 }) {
        Column({ space: 10 }) {
          Text('应用中心')
            .fontSize(34)
            .fontWeight(FontWeight.Bold)
            .fontColor('#101828')
          Text('统一分发、安装和管理五个基础应用。')
            .fontSize(16)
            .fontColor('#56667C')
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')

        Row({ space: 12 }) {
          Column({ space: 6 }) {
            Text('' + this.getInstalledCount())
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor('#0F172A')
            Text('已安装')
              .fontSize(13)
              .fontColor('#66758A')
          }
          .layoutWeight(1)
          .padding(16)
          .borderRadius(22)
          .backgroundColor('#FFFFFF')

          Column({ space: 6 }) {
            Text('' + this.getPendingCount())
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor('#0F172A')
            Text('待处理')
              .fontSize(13)
              .fontColor('#66758A')
          }
          .layoutWeight(1)
          .padding(16)
          .borderRadius(22)
          .backgroundColor('#FFFFFF')
        }
        .width('100%')

        Column({ space: 16 }) {
          Grid() {
            ForEach(this.apps, (app: ManagedApp) => {
              GridItem() {
                this.buildAppIcon(app)
              }
            }, (app: ManagedApp) => app.id)
          }
          .columnsTemplate('1fr 1fr 1fr')
          .columnsGap(10)
          .rowsGap(16)
          .width('100%')
        }
        .padding(18)
        .borderRadius(28)
        .backgroundColor('#F8FBFF')

        Column({ space: 14 }) {
          Row() {
            Text(this.safeText(this.getSelectedApp().label, '应用中心'))
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor('#0F172A')
            Blank()
            Text(this.getSelectedApp().installed ? '已安装' : '未安装')
              .fontSize(12)
              .fontColor(this.getSelectedApp().installed ? '#0F766E' : '#C05621')
              .padding({ left: 10, right: 10, top: 5, bottom: 5 })
              .borderRadius(999)
              .backgroundColor(this.getSelectedApp().installed ? '#D7FAF5' : '#FDE8D8')
          }
          .width('100%')

          Text(this.safeText(this.getSelectedApp().description, '应用描述暂不可用。'))
            .fontSize(15)
            .fontColor('#475467')
            .lineHeight(22)

          Row({ space: 8 }) {
            Text(this.getSelectedApp().id === 'app-center' ? '统一入口' : '中心分发')
              .fontSize(12)
              .fontColor('#1D4ED8')
              .padding({ left: 10, right: 10, top: 5, bottom: 5 })
              .borderRadius(999)
              .backgroundColor('#E0ECFF')
            Text(this.getSelectedApp().id === 'app-center' ? '桌面主入口常驻' : '打开时可能有系统确认')
              .fontSize(12)
              .fontColor('#7C2D12')
              .padding({ left: 10, right: 10, top: 5, bottom: 5 })
              .borderRadius(999)
              .backgroundColor('#FDE8D8')
          }
          .width('100%')

          Text(this.getLaunchHint(this.getSelectedApp()))
            .fontSize(13)
            .fontColor('#66758A')
            .lineHeight(20)

          Row({ space: 10 }) {
            Text(this.getSelectedApp().showOnDesktop ? '桌面显示中' : '桌面隐藏中')
              .fontSize(12)
              .fontColor(this.getSelectedApp().showOnDesktop ? '#1D4ED8' : '#66758A')
              .padding({ left: 10, right: 10, top: 5, bottom: 5 })
              .borderRadius(999)
              .backgroundColor(this.getSelectedApp().showOnDesktop ? '#E0ECFF' : '#F1F5F9')
            Text(this.supportsDesktopShortcut(this.getSelectedApp()) ? '由应用中心统一控制' : '系统主入口')
              .fontSize(12)
              .fontColor('#475467')
          }
          .width('100%')

          Row({ space: 10 }) {
            Button(this.getSelectedApp().installed ? '进入应用' : '尝试安装')
              .layoutWeight(1)
              .height(46)
              .backgroundColor(this.safeText(this.getSelectedApp().accentColor, '#1C65FF'))
              .fontColor('#FFFFFF')
              .fontSize(16)
              .onClick(() => {
                const selectedApp = this.getSelectedApp();
                if (selectedApp.installed) {
                  void this.handleOpen(selectedApp);
                } else {
                  void this.handleInstall(selectedApp);
                }
              })

            Button(this.getSelectedApp().canUninstall ? '管理应用' : '当前应用')
              .layoutWeight(1)
              .height(46)
              .backgroundColor('#FFFFFF')
              .fontColor('#243B53')
              .fontSize(16)
              .onClick(() => {
                const selectedApp = this.getSelectedApp();
                void this.handleUninstall(selectedApp);
              })
          }
          .width('100%')

          Row({ space: 10 }) {
            Button(this.supportsDesktopShortcut(this.getSelectedApp()) ?
              (this.getSelectedApp().showOnDesktop ? '隐藏桌面入口' : '在桌面显示') :
              '桌面主入口')
              .layoutWeight(1)
              .height(42)
              .backgroundColor('#EAF2FF')
              .fontColor('#1D4ED8')
              .onClick(() => {
                const selectedApp = this.getSelectedApp();
                void this.setDesktopVisibility(selectedApp, !selectedApp.showOnDesktop);
              })
            Button(this.isRefreshing ? '刷新中...' : '刷新状态')
              .layoutWeight(1)
              .height(42)
              .backgroundColor('#EEF2F6')
              .fontColor('#334155')
              .onClick(() => {
                void this.refreshInstalledState();
              })
          }
          .width('100%')

          Button('系统应用管理')
            .width('100%')
            .height(42)
            .backgroundColor('#F7F9FC')
            .fontColor('#334155')
            .onClick(() => {
              void this.openApplicationManager();
            })
        }
        .width('100%')
        .padding(20)
        .borderRadius(28)
        .backgroundColor('#FFFFFF')

        Column({ space: 6 }) {
          Text(this.statusTitle)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#0F172A')
          Text(this.statusDetail)
            .fontSize(14)
            .fontColor('#5B6B80')
            .lineHeight(20)
        }
        .width('100%')
        .padding(18)
        .borderRadius(24)
        .backgroundColor('#EDF4FF')

        Column({ space: 6 }) {
          Text('交互说明')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#0F172A')
          Text('1. 应用中心负责分发其他应用。 2. 从中心进入其他应用时，系统可能弹出一次确认。 3. 其他应用返回应用中心时按当前方案不再重复确认。')
            .fontSize(13)
            .fontColor('#5B6B80')
            .lineHeight(20)
        }
        .width('100%')
        .padding(18)
        .borderRadius(24)
        .backgroundColor('#FFF7ED')
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 24, bottom: 36 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#DCE9FF')
  }
}
