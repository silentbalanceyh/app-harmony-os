import hilog from '@ohos.hilog';

const DEFAULT_DOMAIN: number = 0x0A10;
const DEFAULT_TAG: string = 'r2mo-app';

export default class Logger {
  private readonly tag: string;
  private readonly domain: number;

  constructor(tag?: string, domain?: number) {
    this.tag = tag && tag.length > 0 ? tag : DEFAULT_TAG;
    this.domain = domain !== undefined ? domain : DEFAULT_DOMAIN;
  }

  info(message: string): void {
    hilog.info(this.domain, this.tag, '%{public}s', message);
  }

  warn(message: string): void {
    hilog.warn(this.domain, this.tag, '%{public}s', message);
  }

  error(message: string): void {
    hilog.error(this.domain, this.tag, '%{public}s', message);
  }

  debug(message: string): void {
    hilog.debug(this.domain, this.tag, '%{public}s', message);
  }

  static create(appTag: string): Logger {
    return new Logger(appTag);
  }

  static stringify(value: Object | string | number | boolean | undefined | null): string {
    if (value === undefined) {
      return 'undefined';
    }
    if (value === null) {
      return 'null';
    }
    if (typeof value === 'string') {
      return value;
    }
    try {
      return JSON.stringify(value);
    } catch (err) {
      return String(value);
    }
  }
}
