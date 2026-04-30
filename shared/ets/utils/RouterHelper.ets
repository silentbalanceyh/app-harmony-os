import router from '@ohos.router';

export interface RouteOptions<T extends Object> {
  url: string;
  params?: T;
}

export default class RouterHelper {
  static async push<T extends Object>(options: RouteOptions<T>): Promise<void> {
    await router.pushUrl({
      url: options.url,
      params: options.params
    });
  }

  static async replace<T extends Object>(options: RouteOptions<T>): Promise<void> {
    await router.replaceUrl({
      url: options.url,
      params: options.params
    });
  }

  static back(): void {
    router.back();
  }

  static getParams<T extends Object>(): T | undefined {
    return router.getParams() as T | undefined;
  }
}
