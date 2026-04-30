import dataPreferences from '@ohos.data.preferences';
import common from '@ohos.app.ability.common';
import { CryptoUtil } from './CryptoUtil';

const PREFS_NAME = 'album_security';
const KEY_PASSWORD_HASH = 'password_hash';
const KEY_PASSWORD_SET = 'password_set';

function simpleHash(input: string): string {
  let hash = 0;
  for (let i = 0; i < input.length; i++) {
    const ch = input.charCodeAt(i);
    hash = ((hash << 5) - hash) + ch;
    hash = hash & hash;
  }
  return hash.toString(16);
}

export class PasswordStore {
  private prefs: dataPreferences.Preferences | null = null;

  async init(context: common.UIAbilityContext): Promise<void> {
    this.prefs = await dataPreferences.getPreferences(context, PREFS_NAME);
  }

  async isPasswordSet(): Promise<boolean> {
    if (!this.prefs) return false;
    return await this.prefs.get(KEY_PASSWORD_SET, false) as boolean;
  }

  async setPassword(password: string): Promise<void> {
    if (!this.prefs) return;
    const salt = CryptoUtil.generateSalt();
    const hash = await CryptoUtil.hashPassword(password, salt);
    await this.prefs.put(KEY_PASSWORD_HASH, hash);
    await this.prefs.put(KEY_PASSWORD_SET, true);
    await this.prefs.flush();
  }

  async verifyPassword(password: string): Promise<boolean> {
    if (!this.prefs) return false;
    const stored = await this.prefs.get(KEY_PASSWORD_HASH, '') as string;
    if (!stored) return false;

    if (CryptoUtil.isLegacyHash(stored)) {
      const legacyMatch = simpleHash(password) === stored;
      if (legacyMatch) {
        const newHash = await CryptoUtil.migrateLegacyHash(password, stored);
        await this.prefs.put(KEY_PASSWORD_HASH, newHash);
        await this.prefs.flush();
      }
      return legacyMatch;
    }

    return await CryptoUtil.verifyPassword(password, stored);
  }

  async clearPassword(): Promise<void> {
    if (!this.prefs) return;
    await this.prefs.delete(KEY_PASSWORD_HASH);
    await this.prefs.put(KEY_PASSWORD_SET, false);
    await this.prefs.flush();
  }
}
