import common from '@ohos.app.ability.common';
import Want from '@ohos.app.ability.Want';
import SoundEffectPlayer from '../utils/SoundEffectPlayer';

interface TargetApp {
  id: string;
  label: string;
  bundleName: string;
  moduleName: string;
  abilityName: string;
  serviceName: string;
}

const COMMAND_OPEN_ENTRY: string = 'open-entry';
const START_WITHOUT_TIPS_FLAG: number = 0x100000;
const LAUNCH_SOUND_FILE: string = 'launch.wav';
const RETURN_SOUND_FILE: string = 'return.wav';

@Entry
@Component
struct Index {
  private readonly centerApp: TargetApp = {
    id: 'app-center',
    label: '应用中心',
    bundleName: 'com.zerows.appcenter',
    moduleName: 'entry',
    abilityName: 'EntryAbility',
    serviceName: 'AppBridgeService'
  };
  private readonly monitorApp: TargetApp = {
    id: 'app-monitor',
    label: '监控中心',
    bundleName: 'com.zerows.appmonitor',
    moduleName: 'entry',
    abilityName: 'EntryAbility',
    serviceName: 'AppBridgeService'
  };
  @State controls: string[] = ['设备校验', '令牌刷新', '安装来源审计'];
  @State banner: string = '安全策略已生效，可从应用中心进入并直接返回';
  private readonly soundEffectPlayer: SoundEffectPlayer = new SoundEffectPlayer();

  private getAbilityContext(): common.UIAbilityContext {
    const hostContext = this.getUIContext().getHostContext();
    if (!hostContext) {
      throw new Error('UIAbilityContext is unavailable');
    }
    return hostContext as common.UIAbilityContext;
  }

  private buildEntryWant(target: TargetApp, scene: string): Want {
    return {
      bundleName: target.bundleName,
      moduleName: target.moduleName,
      abilityName: target.abilityName,
      flags: START_WITHOUT_TIPS_FLAG,
      parameters: {
        command: COMMAND_OPEN_ENTRY,
        starterApp: 'app-security',
        coordinationScene: scene,
        sourceLabel: '安全中心',
        startedAt: Date.now()
      }
    };
  }

  private async launchApp(target: TargetApp, scene: string): Promise<void> {
    try {
      await this.getAbilityContext().startAbility(this.buildEntryWant(target, scene));
      this.banner = '已拉起 ' + target.label;
    } catch (err) {
      this.banner = '拉起 ' + target.label + ' 失败';
      console.error('Launch failed: ' + JSON.stringify(err));
    }
  }

  private async playAndLaunch(target: TargetApp, scene: string, soundFile: string): Promise<void> {
    await this.soundEffectPlayer.play(this.getAbilityContext(), soundFile);
    await this.launchApp(target, scene);
  }

  build() {
    Column({ space: 18 }) {
      Text('安全中心')
        .fontSize(34)
        .fontWeight(FontWeight.Bold)
      Text('为云连接场景提供鉴权、设备安全和风险拦截能力。')
        .fontSize(16)
        .fontColor('#5B3246')
        .textAlign(TextAlign.Center)
      Text('从应用中心进入时系统可能确认一次，返回应用中心不再重复确认。')
        .fontSize(13)
        .fontColor('#7C3A2D')
        .textAlign(TextAlign.Center)
      Text(this.banner)
        .fontSize(18)
        .fontColor('#9A3412')
      ForEach(this.controls, (control: string) => {
        Text(control)
          .width('100%')
          .padding(14)
          .borderRadius(16)
          .backgroundColor('#FFFFFF')
          .fontSize(16)
      })
      Button('执行安全巡检')
        .width('100%')
        .fontSize(18)
        .onClick(() => {
          this.banner = '最近一次巡检通过，未发现高危风险';
        })
      Button('返回统一入口')
        .width('100%')
        .fontSize(18)
        .onClick(() => {
          void this.playAndLaunch(this.centerApp, 'security-back-to-center', RETURN_SOUND_FILE);
        })
      Button('拉起监控中心')
        .width('100%')
        .fontSize(18)
        .onClick(() => {
          void this.playAndLaunch(this.monitorApp, 'security-open-monitor', LAUNCH_SOUND_FILE);
        })
    }
    .width('100%')
    .height('100%')
    .padding(24)
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#FFF4E5')
  }
}
