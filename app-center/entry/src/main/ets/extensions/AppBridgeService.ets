import AppServiceExtensionAbility from '@ohos.app.ability.AppServiceExtensionAbility';
import Want from '@ohos.app.ability.Want';

const APP_TAG: string = 'app-center';
const APP_BUNDLE_NAME: string = 'com.zerows.appcenter';
const ENTRY_MODULE_NAME: string = 'entry';
const ENTRY_ABILITY_NAME: string = 'EntryAbility';
const COMMAND_OPEN_ENTRY: string = 'open-entry';

export default class AppBridgeService extends AppServiceExtensionAbility {
  onRequest(want: Want, startId: number): void {
    console.info(APP_TAG + ' bridge request startId=' + startId + ' params=' + JSON.stringify(want.parameters ?? {}));
    void this.handleRequest(want);
  }

  private async handleRequest(want: Want): Promise<void> {
    const command: string = String(want.parameters?.command ?? '');

    try {
      if (command === COMMAND_OPEN_ENTRY) {
        await this.context.startAbility({
          bundleName: APP_BUNDLE_NAME,
          moduleName: ENTRY_MODULE_NAME,
          abilityName: ENTRY_ABILITY_NAME,
          parameters: want.parameters
        });
      }
    } catch (err) {
      console.error(APP_TAG + ' bridge request failed: ' + JSON.stringify(err));
    } finally {
      await this.stopSelf();
    }
  }

  private async stopSelf(): Promise<void> {
    try {
      await this.context.terminateSelf();
    } catch (err) {
      console.error(APP_TAG + ' bridge terminate failed: ' + JSON.stringify(err));
    }
  }
}
