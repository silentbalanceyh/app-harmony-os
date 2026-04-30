import common from '@ohos.app.ability.common';
import Want from '@ohos.app.ability.Want';
import wantConstant from '@ohos.app.ability.wantConstant';
import { AppTarget, BridgeCommand, BridgeParameters } from './AppBridgeTypes';

const START_WITHOUT_TIPS_FLAG: number = wantConstant.Flags.FLAG_START_WITHOUT_TIPS;

export interface BridgeLaunchOptions {
  command: BridgeCommand;
  sourceBundleName: string;
  sourceModuleName: string;
  sourceAbilityName: string;
  sourceLabel?: string;
  sourceAppId?: string;
  targetAppId?: string;
  coordinationScene?: string;
  starterApp?: string;
  selectedAppId?: string;
}

export default class AppBridgeClient {
  static buildEntryWant(target: AppTarget, options: BridgeLaunchOptions): Want {
    const parameters: BridgeParameters = {
      command: options.command,
      sourceBundleName: options.sourceBundleName,
      sourceModuleName: options.sourceModuleName,
      sourceAbilityName: options.sourceAbilityName,
      sourceLabel: options.sourceLabel,
      sourceAppId: options.sourceAppId,
      targetAppId: options.targetAppId,
      coordinationScene: options.coordinationScene,
      starterApp: options.starterApp,
      selectedAppId: options.selectedAppId,
      timestamp: Date.now(),
      startedAt: Date.now()
    };

    return {
      bundleName: target.bundleName,
      moduleName: target.moduleName,
      abilityName: target.abilityName,
      flags: START_WITHOUT_TIPS_FLAG,
      parameters
    };
  }

  static async startEntry(context: common.UIAbilityContext, target: AppTarget, options: BridgeLaunchOptions): Promise<void> {
    await context.startAbility(AppBridgeClient.buildEntryWant(target, options));
  }

  static buildServiceWant(target: AppTarget, parameters: BridgeParameters): Want {
    return {
      bundleName: target.bundleName,
      moduleName: target.moduleName,
      abilityName: target.serviceName ? target.serviceName : target.abilityName,
      parameters
    };
  }
}
