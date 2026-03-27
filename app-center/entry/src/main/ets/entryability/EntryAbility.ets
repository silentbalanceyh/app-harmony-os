import UIAbility from '@ohos.app.ability.UIAbility';
import AbilityConstant from '@ohos.app.ability.AbilityConstant';
import Want from '@ohos.app.ability.Want';
import window from '@ohos.window';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam) {
    console.info('app-center EntryAbility onCreate: ' + JSON.stringify(want?.parameters ?? {}));
  }

  onDestroy() {
    console.info('app-center EntryAbility onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage) {
    console.info('app-center EntryAbility onWindowStageCreate');
    windowStage.loadContent('pages/Index', (err, data) => {
      if (err.code) {
        console.error('Failed to load app-center content. Cause: ' + JSON.stringify(err));
        return;
      }
      console.info('Succeeded in loading app-center content. Data: ' + JSON.stringify(data));
    });
  }

  onWindowStageDestroy() {
    console.info('app-center EntryAbility onWindowStageDestroy');
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam) {
    console.info('app-center EntryAbility onNewWant: ' + JSON.stringify(want?.parameters ?? {}));
  }

  onForeground() {
    console.info('app-center EntryAbility onForeground');
  }

  onBackground() {
    console.info('app-center EntryAbility onBackground');
  }
}
