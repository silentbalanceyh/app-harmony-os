/**
 * 强提醒服务
 * 系统级闹钟提醒、震动反馈
 */

import reminderAgentManager from '@ohos.reminderAgentManager';
import vibrator from '@ohos.vibrator';
import common from '@ohos.app.ability.common';
import { MedicineReminder, ReminderStatus } from '../models/ReminderModel';
import { ReminderStore } from './ReminderStore';

const MAX_RETRY_COUNT = 3;
const RETRY_INTERVAL_SECONDS = 300;

export interface ReminderTrigger {
  reminderId: string;
  medicineName: string;
  triggeredAt: number;
}

export class StrongReminderService {
  private context: common.UIAbilityContext | null = null;
  private reminderStore: ReminderStore | null = null;
  private activeReminders: Map<string, number> = new Map();
  private onTriggerCallback: ((trigger: ReminderTrigger) => void) | null = null;

  async init(
    context: common.UIAbilityContext,
    store: ReminderStore,
    onTrigger?: ((trigger: ReminderTrigger) => void)
  ): Promise<void> {
    this.context = context;
    this.reminderStore = store;
    if (onTrigger) {
      this.onTriggerCallback = onTrigger;
    }
    console.info('[StrongReminderService] Initialized');
  }

  async registerReminder(reminder: MedicineReminder): Promise<number> {
    try {
      const timeParts = reminder.time.split(':');
      const hour = parseInt(timeParts[0], 10);
      const minute = parseInt(timeParts[1], 10);

      const now = new Date();
      const targetTime = new Date();
      targetTime.setHours(hour, minute, 0, 0);

      if (targetTime <= now) {
        targetTime.setDate(targetTime.getDate() + 1);
      }

      const triggerTimeInSeconds = Math.floor((targetTime.getTime() - now.getTime()) / 1000);

      const reminderRequest: reminderAgentManager.ReminderRequestTimer = {
        reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_TIMER,
        triggerTimeInSeconds: triggerTimeInSeconds,
        title: '用药提醒',
        content: reminder.medicineName + ' ' + reminder.dosage
      };

      const agentId = await reminderAgentManager.publishReminder(reminderRequest);
      this.activeReminders.set(reminder.id, agentId);

      console.info('[StrongReminderService] Registered: ' + reminder.id);
      return agentId;
    } catch (err) {
      console.error('[StrongReminderService] Register failed: ' + JSON.stringify(err));
      return -1;
    }
  }

  async cancelReminder(reminderId: string): Promise<boolean> {
    const agentId = this.activeReminders.get(reminderId);
    if (!agentId) {
      return false;
    }

    try {
      await reminderAgentManager.cancelReminder(agentId);
      this.activeReminders.delete(reminderId);
      console.info('[StrongReminderService] Cancelled: ' + reminderId);
      return true;
    } catch (err) {
      console.error('[StrongReminderService] Cancel failed: ' + JSON.stringify(err));
      return false;
    }
  }

  async vibrate(duration: number = 100): Promise<void> {
    try {
      vibrator.vibrate(duration);
      console.info('[StrongReminderService] Vibrating');
    } catch (err) {
      console.error('[StrongReminderService] Vibrate failed: ' + JSON.stringify(err));
    }
  }

  async confirmTaken(reminderId: string): Promise<void> {
    try {
      vibrator.stop(vibrator.VibratorStopMode.VIBRATOR_STOP_MODE_TIME);
    } catch (e) {
      // 忽略
    }

    if (this.reminderStore) {
      await this.reminderStore.updateStatus(reminderId, ReminderStatus.TAKEN);
    }

    await this.cancelReminder(reminderId + '_retry');
    console.info('[StrongReminderService] Confirmed taken: ' + reminderId);
  }

  async stopReminderAction(reminderId: string): Promise<void> {
    try {
      vibrator.stop(vibrator.VibratorStopMode.VIBRATOR_STOP_MODE_TIME);
    } catch (e) {
      // 忽略
    }

    if (this.reminderStore) {
      await this.reminderStore.updateStatus(reminderId, ReminderStatus.REMINDED);
    }
    console.info('[StrongReminderService] Stopped: ' + reminderId);
  }

  async scheduleRetry(reminder: MedicineReminder): Promise<void> {
    const retryCount = reminder.retryCount;
    if (retryCount >= MAX_RETRY_COUNT) {
      return;
    }

    try {
      const reminderRequest: reminderAgentManager.ReminderRequestTimer = {
        reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_TIMER,
        triggerTimeInSeconds: RETRY_INTERVAL_SECONDS,
        title: '用药提醒（重提醒）',
        content: reminder.medicineName + ' 尚未服药'
      };

      const agentId = await reminderAgentManager.publishReminder(reminderRequest);
      this.activeReminders.set(reminder.id + '_retry', agentId);

      if (this.reminderStore) {
        await this.reminderStore.incrementRetry(reminder.id);
      }
      console.info('[StrongReminderService] Scheduled retry #' + (retryCount + 1));
    } catch (err) {
      console.error('[StrongReminderService] Retry failed: ' + JSON.stringify(err));
    }
  }

  async destroy(): Promise<void> {
    const entries = Array.from(this.activeReminders.entries());
    for (const entry of entries) {
      const agentId = entry[1];
      try {
        await reminderAgentManager.cancelReminder(agentId);
      } catch (e) {
        // 忽略
      }
    }
    this.activeReminders.clear();
    console.info('[StrongReminderService] Destroyed');
  }
}

export const strongReminderService = new StrongReminderService();