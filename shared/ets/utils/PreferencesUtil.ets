import common from '@ohos.app.ability.common';
import preferences from '@ohos.data.preferences';

export default class PreferencesUtil {
  private readonly context: common.Context;
  private readonly storeName: string;
  private store?: preferences.Preferences;

  constructor(context: common.Context, storeName: string) {
    this.context = context;
    this.storeName = storeName;
  }

  async getString(key: string, defaultValue: string): Promise<string> {
    const store: preferences.Preferences = await this.getStore();
    return String(await store.get(key, defaultValue));
  }

  async putString(key: string, value: string): Promise<void> {
    const store: preferences.Preferences = await this.getStore();
    await store.put(key, value);
    await store.flush();
  }

  async getBoolean(key: string, defaultValue: boolean): Promise<boolean> {
    const store: preferences.Preferences = await this.getStore();
    const value: preferences.ValueType = await store.get(key, defaultValue);
    return value === true;
  }

  async putBoolean(key: string, value: boolean): Promise<void> {
    const store: preferences.Preferences = await this.getStore();
    await store.put(key, value);
    await store.flush();
  }

  async getNumber(key: string, defaultValue: number): Promise<number> {
    const store: preferences.Preferences = await this.getStore();
    const value: preferences.ValueType = await store.get(key, defaultValue);
    return Number(value);
  }

  async putNumber(key: string, value: number): Promise<void> {
    const store: preferences.Preferences = await this.getStore();
    await store.put(key, value);
    await store.flush();
  }

  async remove(key: string): Promise<void> {
    const store: preferences.Preferences = await this.getStore();
    await store.delete(key);
    await store.flush();
  }

  private async getStore(): Promise<preferences.Preferences> {
    if (!this.store) {
      this.store = await preferences.getPreferences(this.context, this.storeName);
    }
    return this.store;
  }
}
