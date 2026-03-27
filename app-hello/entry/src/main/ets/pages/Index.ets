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
  private readonly securityApp: TargetApp = {
    id: 'app-security',
    label: '安全中心',
    bundleName: 'com.zerows.appsecurity',
    moduleName: 'entry',
    abilityName: 'EntryAbility',
    serviceName: 'AppBridgeService'
  };
  @State handshake: string = '等待与系统应用完成分发握手';
  private readonly collaborators: string[] = ['app-center 负责纳管', 'app-monitor 负责监控', 'app-security 负责鉴权'];
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
        starterApp: 'app-hello',
        coordinationScene: scene,
        sourceLabel: 'Hello 应用',
        startedAt: Date.now()
      }
    };
  }

  private async launchApp(target: TargetApp, scene: string): Promise<void> {
    try {
      await this.getAbilityContext().startAbility(this.buildEntryWant(target, scene));
      this.handshake = '已拉起 ' + target.label;
    } catch (err) {
      this.handshake = '拉起 ' + target.label + ' 失败';
      console.error('Launch failed: ' + JSON.stringify(err));
    }
  }

  private async playAndLaunch(target: TargetApp, scene: string, soundFile: string): Promise<void> {
    await this.soundEffectPlayer.play(this.getAbilityContext(), soundFile);
    await this.launchApp(target, scene);
  }

  build() {
    Column({ space: 18 }) {
      Text('Hello 应用')
        .fontSize(34)
        .fontWeight(FontWeight.Bold)
      Text('首个业务示例应用，需要与系统应用完成协同联动。')
        .fontSize(16)
        .fontColor('#3E4C59')
        .textAlign(TextAlign.Center)
      Text('从应用中心进入时系统可能确认一次，返回应用中心不再重复确认。')
        .fontSize(13)
        .fontColor('#66758A')
        .textAlign(TextAlign.Center)
      Text(this.handshake)
        .fontSize(18)
        .fontColor('#1D4ED8')
      ForEach(this.collaborators, (item: string) => {
        Text(item)
          .width('100%')
          .padding(14)
          .borderRadius(16)
          .backgroundColor('#FFFFFF')
          .fontSize(16)
      })
      Button('发起协同检查')
        .width('100%')
        .fontSize(18)
        .onClick(() => {
          this.handshake = '已与中心、监控、安全应用完成基础协同';
        })
      Button('返回统一入口')
        .width('100%')
        .fontSize(18)
        .onClick(() => {
          void this.playAndLaunch(this.centerApp, 'hello-back-to-center', RETURN_SOUND_FILE);
        })
      Button('拉起安全中心')
        .width('100%')
        .fontSize(18)
        .onClick(() => {
          void this.playAndLaunch(this.securityApp, 'hello-open-security', LAUNCH_SOUND_FILE);
        })
    }
    .width('100%')
    .height('100%')
    .padding(24)
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#EEF2FF')
  }
}
