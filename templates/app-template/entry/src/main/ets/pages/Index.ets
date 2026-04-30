import common from '@ohos.app.ability.common';
import Want from '@ohos.app.ability.Want';
import SoundEffectPlayer from '../utils/SoundEffectPlayer';

interface TargetApp {
  id: string;
  label: string;
  bundleName: string;
  moduleName: string;
  abilityName: string;
}

const APP_ID: string = '_APP_NAME_';
const APP_LABEL: string = '_LABEL_';
const COMMAND_OPEN_ENTRY: string = 'open-entry';
const START_WITHOUT_TIPS_FLAG: number = 0x100000;
const RETURN_SOUND_FILE: string = 'return.wav';

@Entry
@Component
struct Index {
  private readonly centerApp: TargetApp = {
    id: 'app-center',
    label: '应用中心',
    bundleName: 'com.zerows.appcenter',
    moduleName: 'entry',
    abilityName: 'EntryAbility'
  };
  @State private statusText: string = '已接入统一应用中心';
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
        starterApp: APP_ID,
        coordinationScene: scene,
        sourceLabel: APP_LABEL,
        startedAt: Date.now()
      }
    };
  }

  private async returnToCenter(): Promise<void> {
    try {
      await this.soundEffectPlayer.play(this.getAbilityContext(), RETURN_SOUND_FILE);
      await this.getAbilityContext().startAbility(this.buildEntryWant(this.centerApp, APP_ID + '-back-to-center'));
      this.statusText = '正在返回应用中心';
    } catch (err) {
      this.statusText = '返回应用中心失败';
      console.error('Return to app-center failed: ' + JSON.stringify(err));
    }
  }

  build() {
    Column({ space: 18 }) {
      Text(APP_LABEL)
        .fontSize(32)
        .fontWeight(FontWeight.Bold)
        .fontColor('#172033')
      Text(this.statusText)
        .fontSize(17)
        .fontColor('#3E4C59')
        .textAlign(TextAlign.Center)
      Text(APP_ID + ' / _BUNDLE_NAME_')
        .fontSize(13)
        .fontColor('#66758A')
        .textAlign(TextAlign.Center)
      Button('返回统一入口')
        .width('100%')
        .fontSize(18)
        .onClick(() => {
          void this.returnToCenter();
        })
    }
    .width('100%')
    .height('100%')
    .padding(24)
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#F4F7FB')
  }
}
