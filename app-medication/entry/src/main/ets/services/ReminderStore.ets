/**
 * 提醒数据存储服务
 * 使用 Preferences 进行本地存储
 */

import preferences from '@ohos.data.preferences';
import common from '@ohos.app.ability.common';
import {
  MedicineReminder,
  ReminderFrequency,
  ReminderStatus,
  generateReminderId
} from '../models/ReminderModel';

const STORE_NAME = 'medication_reminders';

export class ReminderStore {
  private prefs: preferences.Preferences | null = null;
  private context: common.UIAbilityContext | null = null;

  async init(context: common.UIAbilityContext): Promise<void> {
    this.context = context;
    try {
      this.prefs = await preferences.getPreferences(context, STORE_NAME);
      console.info('[ReminderStore] Initialized');
    } catch (err) {
      console.error('[ReminderStore] Init failed: ' + JSON.stringify(err));
      const error = new Error('ReminderStore init failed');
      throw error;
    }
  }

  async getAllReminders(): Promise<MedicineReminder[]> {
    if (!this.prefs) {
      return [];
    }

    try {
      const data = await this.prefs.get('reminders', '[]');
      const reminders: MedicineReminder[] = JSON.parse(data as string);
      return reminders;
    } catch (err) {
      console.error('[ReminderStore] Get all failed: ' + JSON.stringify(err));
      return [];
    }
  }

  async getTodayReminders(): Promise<MedicineReminder[]> {
    const all = await this.getAllReminders();
    const today = new Date();
    const isOddDay = today.getDate() % 2 === 1;

    return all.filter((r: MedicineReminder) => {
      if (r.frequency === ReminderFrequency.DAILY) {
        return true;
      }
      if (r.frequency === ReminderFrequency.EVERY_OTHER_DAY) {
        return isOddDay;
      }
      if (r.frequency === ReminderFrequency.WEEKLY) {
        return true;
      }
      return false;
    }).sort((a: MedicineReminder, b: MedicineReminder) => a.time.localeCompare(b.time));
  }

  async addReminder(
    time: string,
    medicineName: string,
    dosage: string,
    medicineImage?: string,
    frequency: ReminderFrequency = ReminderFrequency.DAILY
  ): Promise<MedicineReminder> {
    if (!this.prefs) {
      throw new Error('[ReminderStore] Not initialized');
    }

    const reminder: MedicineReminder = {
      id: generateReminderId(),
      time,
      medicineName,
      medicineImage,
      dosage,
      frequency,
      status: ReminderStatus.PENDING,
      createdAt: Date.now(),
      retryCount: 0
    };

    const all = await this.getAllReminders();
    all.push(reminder);

    await this.prefs.put('reminders', JSON.stringify(all));
    await this.prefs.flush();

    console.info('[ReminderStore] Added: ' + reminder.id);
    return reminder;
  }

  async deleteReminder(id: string): Promise<boolean> {
    if (!this.prefs) {
      return false;
    }

    const all = await this.getAllReminders();
    const filtered = all.filter((r: MedicineReminder) => r.id !== id);

    if (filtered.length === all.length) {
      return false;
    }

    await this.prefs.put('reminders', JSON.stringify(filtered));
    await this.prefs.flush();

    console.info('[ReminderStore] Deleted: ' + id);
    return true;
  }

  async updateStatus(id: string, status: ReminderStatus): Promise<boolean> {
    if (!this.prefs) {
      return false;
    }

    const all = await this.getAllReminders();
    const found = all.find((r: MedicineReminder) => r.id === id);

    if (!found) {
      return false;
    }

    found.status = status;
    if (status === ReminderStatus.REMINDED) {
      found.lastRemindedAt = Date.now();
    }

    await this.prefs.put('reminders', JSON.stringify(all));
    await this.prefs.flush();

    return true;
  }

  async incrementRetry(id: string): Promise<number> {
    if (!this.prefs) {
      return -1;
    }

    const all = await this.getAllReminders();
    const found = all.find((r: MedicineReminder) => r.id === id);

    if (!found) {
      return -1;
    }

    found.retryCount = Math.min(found.retryCount + 1, 3);
    await this.prefs.put('reminders', JSON.stringify(all));
    await this.prefs.flush();

    return found.retryCount;
  }

  async clearAll(): Promise<void> {
    if (!this.prefs) {
      return;
    }

    await this.prefs.put('reminders', '[]');
    await this.prefs.flush();
    console.info('[ReminderStore] Cleared');
  }
}

export const reminderStore = new ReminderStore();