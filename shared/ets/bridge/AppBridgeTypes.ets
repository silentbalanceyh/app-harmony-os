export enum BridgeCommand {
  OPEN_ENTRY = 'open-entry',
  RETURN_TO_CENTER = 'return-to-center',
  QUERY_STATUS = 'query-status',
  NOTIFY_EVENT = 'notify-event',
  SET_SHORTCUT_VISIBLE = 'set-shortcut-visible'
}

export interface BridgeParameters {
  command: BridgeCommand | string;
  sourceBundleName?: string;
  sourceModuleName?: string;
  sourceAbilityName?: string;
  sourceLabel?: string;
  sourceAppId?: string;
  targetAppId?: string;
  coordinationScene?: string;
  starterApp?: string;
  selectedAppId?: string;
  desktopVisible?: boolean | string;
  timestamp?: number;
  startedAt?: number;
  eventName?: string;
  eventPayload?: string;
}

export interface BridgeResponse {
  success: boolean;
  errorCode?: string;
  message?: string;
}

export interface AppTarget {
  id: string;
  label: string;
  bundleName: string;
  moduleName: string;
  abilityName: string;
  serviceName?: string;
}

export function toBridgeParameters(value: Object | undefined): BridgeParameters {
  if (!value) {
    return {
      command: ''
    };
  }
  return value as BridgeParameters;
}
