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
  private readonly helloApp: TargetApp = {
    id: 'app-hello',
    label: 'Hello 应用',
    bundleName: 'com.zerows.apphello',
    moduleName: 'entry',
    abilityName: 'EntryAbility',
    serviceName: 'AppBridgeService'
  };
  @State metrics: string[] = ['云连接: 正常', '应用心跳: 4/4', '告警队列: 0'];
  @State summary: string = '监控链路稳定，可从应用中心进入并直接返回';
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
        starterApp: 'app-monitor',
        coordinationScene: scene,
        sourceLabel: '监控中心',
        startedAt: Date.now()
      }
    };
  }

  private async launchApp(target: TargetApp, scene: string): Promise<void> {
    try {
      await this.getAbilityContext().startAbility(this.buildEntryWant(target, scene));
      this.summary = '已拉起 ' + target.label;
    } catch (err) {
      this.summary = '拉起 ' + target.label + ' 失败';
      console.error('Launch failed: ' + JSON.stringify(err));
    }
  }

  private async playAndLaunch(target: TargetApp, scene: string, soundFile: string): Promise<void> {
    await this.soundEffectPlayer.play(this.getAbilityContext(), soundFile);
    await this.launchApp(target, scene);
  }

  build() {
    Column({ space: 18 }) {
      Text('监控中心')
        .fontSize(34)
        .fontWeight(FontWeight.Bold)
      Text('负责采集 app-center、app-security 和 app-hello 的运行状态。')
        .fontSize(16)
        .fontColor('#4B5563')
        .textAlign(TextAlign.Center)
      Text('从应用中心进入时系统可能确认一次，返回应用中心不再重复确认。')
        .fontSize(13)
        .fontColor('#5B6B80')
        .textAlign(TextAlign.Center)
      Text(this.summary)
        .fontSize(18)
        .fontColor('#046C4E')
      ForEach(this.metrics, (metric: string) => {
        Text(metric)
          .width('100%')
          .padding(14)
          .borderRadius(16)
          .backgroundColor('#FFFFFF')
          .fontSize(16)
      })
      Button('模拟巡检')
        .width('100%')
        .fontSize(18)
        .onClick(() => {
          this.summary = '最新巡检已完成，未发现异常';
        })
      Button('返回统一入口')
        .width('100%')
        .fontSize(18)
        .onClick(() => {
          void this.playAndLaunch(this.centerApp, 'monitor-back-to-center', RETURN_SOUND_FILE);
        })
      Button('拉起 Hello 应用')
        .width('100%')
        .fontSize(18)
        .onClick(() => {
          void this.playAndLaunch(this.helloApp, 'monitor-open-hello', LAUNCH_SOUND_FILE);
        })
    }
    .width('100%')
    .height('100%')
    .padding(24)
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#ECFDF3')
  }
}
