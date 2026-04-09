/**
 * 强提醒服务
 * 使用后台任务管理器 + 定时通知实现后台提醒
 */

import backgroundTaskManager from '@ohos.resourceschedule.backgroundTaskManager';
import vibrator from '@ohos.vibrator';
import common from '@ohos.app.ability.common';
import notificationManager from '@ohos.notificationManager';
import wantAgent from '@ohos.app.ability.wantAgent';
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
  private isBackgroundRunning: boolean = false;
  private reminderTimers: Map<string, number> = new Map();
  private backgroundWantAgent: object | null = null;
  // 闹铃震动循环
  private activeAlarmVibrations: Map<string, number> = new Map();
  private isVibrating: boolean = false;
  private activeNotificationIds: Map<string, number> = new Map();
  private alarmTimeouts: Map<string, number> = new Map(); // 60秒超时

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

    // 启动后台长时任务
    await this.startBackgroundTask();

    console.info('[StrongReminderService] Initialized');
  }

  private async startBackgroundTask(): Promise<void> {
    if (this.isBackgroundRunning || !this.context) {
      return;
    }

    try {
      // 创建WantAgent用于后台任务和通知点击
      const wantAgentInfo: wantAgent.WantAgentInfo = {
        wants: [
          {
            bundleName: 'com.zerows.appmedication',
            abilityName: 'EntryAbility'
          }
        ],
        requestCode: 1001,
        operationType: wantAgent.OperationType.START_ABILITY,
        wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      };

      this.backgroundWantAgent = await wantAgent.getWantAgent(wantAgentInfo);
      console.info('[StrongReminderService] WantAgent created');

      await backgroundTaskManager.startBackgroundRunning(
        this.context,
        backgroundTaskManager.BackgroundMode.DATA_TRANSFER,
        this.backgroundWantAgent
      );
      this.isBackgroundRunning = true;
      console.info('[StrongReminderService] Background task started');
    } catch (err) {
      console.error('[StrongReminderService] Start background task failed: ' + JSON.stringify(err));
    }
  }

  private async stopBackgroundTask(): Promise<void> {
    if (!this.isBackgroundRunning || !this.context) {
      return;
    }

    try {
      await backgroundTaskManager.stopBackgroundRunning(this.context);
      this.isBackgroundRunning = false;
      console.info('[StrongReminderService] Background task stopped');
    } catch (err) {
      console.error('[StrongReminderService] Stop background task failed: ' + JSON.stringify(err));
    }
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

      const delayMs = targetTime.getTime() - now.getTime();
      console.info('[StrongReminderService] Registering reminder, delayMs=' + delayMs);

      // 存储提醒ID和时间
      const reminderId = Date.now();
      this.activeReminders.set(reminder.id, reminderId);

      // 使用 setTimeout 触发提醒，触发后自动安排下一次
      this.scheduleNextTrigger(reminder, hour, minute);

      console.info('[StrongReminderService] Registered: ' + reminder.id);
      return reminderId;
    } catch (err) {
      console.error('[StrongReminderService] Register failed: ' + JSON.stringify(err));
      return -1;
    }
  }

  private scheduleNextTrigger(reminder: MedicineReminder, hour: number, minute: number): void {
    const now = new Date();
    const targetTime = new Date();
    targetTime.setHours(hour, minute, 0, 0);

    if (targetTime <= now) {
      targetTime.setDate(targetTime.getDate() + 1);
    }

    const delayMs = targetTime.getTime() - now.getTime();

    // 使用 setTimeout，触发后安排下一次（每天循环）
    const timeout = setTimeout(() => {
      this.triggerReminder(reminder);
      // 触发后安排下一天的提醒
      this.scheduleNextTrigger(reminder, hour, minute);
    }, delayMs);

    // 存储timeout以便取消
    this.reminderTimers.set(reminder.id, timeout);
  }

  private async triggerReminder(reminder: MedicineReminder): Promise<void> {
    try {
      // 发送高优先级通知（带铃声）
      const notificationId = Date.now();
      const notificationRequest: notificationManager.NotificationRequest = {
        id: notificationId,
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: '⏰ 用药提醒',
            text: reminder.medicineName + ' ' + reminder.dosage + ' - 请按时服药',
          }
        },
        notificationSlotType: notificationManager.SlotType.SERVICE_INFORMATION,
        isOngoing: false
      };

      if (this.backgroundWantAgent) {
        notificationRequest.wantAgent = this.backgroundWantAgent;
      }

      await notificationManager.publish(notificationRequest);
      this.activeNotificationIds.set(reminder.id, notificationId);
      console.info('[StrongReminderService] Notification published');

      // 启动闹铃模式（震动+铃声），60秒后自动停止
      this.startAlarmWithTimeout(reminder.id);

      // 更新状态
      if (this.reminderStore) {
        await this.reminderStore.updateStatus(reminder.id, ReminderStatus.REMINDED);
      }

      // 触发回调
      if (this.onTriggerCallback) {
        this.onTriggerCallback({
          reminderId: reminder.id,
          medicineName: reminder.medicineName,
          triggeredAt: Date.now()
        });
      }
    } catch (err) {
      console.error('[StrongReminderService] Trigger failed: ' + JSON.stringify(err));
    }
  }

  /**
   * 启动闹铃模式震动：震动1秒，停0.5秒，循环
   */
  /**
   * 启动闹铃模式：震动+铃声，60秒后自动停止
   */
  private startAlarmWithTimeout(reminderId: string): void {
    // 清理已有的闹铃
    const existingInterval = this.activeAlarmVibrations.get(reminderId);
    if (existingInterval) {
      clearInterval(existingInterval);
    }
    const existingTimeout = this.alarmTimeouts.get(reminderId);
    if (existingTimeout) {
      clearTimeout(existingTimeout);
    }

    this.isVibrating = true;

    // 震动循环：震动1000ms，停500ms
    const vibrationPattern = () => {
      if (!this.isVibrating) return;
      try {
        vibrator.vibrate(1000);
      } catch (e) {
        console.error('[StrongReminderService] Vibrate error: ' + JSON.stringify(e));
      }
    };

    // 立即开始震动
    vibrationPattern();
    const intervalId = setInterval(vibrationPattern, 1500);
    this.activeAlarmVibrations.set(reminderId, intervalId);

    // 60秒后自动停止
    const timeoutId = setTimeout(() => {
      console.info('[StrongReminderService] Alarm timeout, auto stop');
      this.stopAlarmVibration(reminderId);
    }, 60000);
    this.alarmTimeouts.set(reminderId, timeoutId);

    console.info('[StrongReminderService] Alarm started for ' + reminderId + ', will auto stop in 60s');
  }

  /**
   * 停止闹铃
   */
  stopAlarm(reminderId: string): void {
    this.stopAlarmVibration(reminderId);
  }

  /**
   * 停止闹铃震动
   */
  private stopAlarmVibration(reminderId: string): void {
    this.isVibrating = false;

    // 清理震动循环
    const intervalId = this.activeAlarmVibrations.get(reminderId);
    if (intervalId) {
      clearInterval(intervalId);
      this.activeAlarmVibrations.delete(reminderId);
    }

    // 清理超时
    const timeoutId = this.alarmTimeouts.get(reminderId);
    if (timeoutId) {
      clearTimeout(timeoutId);
      this.alarmTimeouts.delete(reminderId);
    }

    // 取消通知
    const notificationId = this.activeNotificationIds.get(reminderId);
    if (notificationId) {
      try {
        notificationManager.cancel(notificationId);
        this.activeNotificationIds.delete(reminderId);
        console.info('[StrongReminderService] Notification cancelled');
      } catch (e) {
        console.error('[StrongReminderService] Cancel notification failed: ' + JSON.stringify(e));
      }
    }

    // 停止当前震动
    try {
      vibrator.stop(vibrator.VibratorStopMode.VIBRATOR_STOP_MODE_TIME);
    } catch (e) {
      // 忽略
    }
    console.info('[StrongReminderService] Alarm vibration stopped for ' + reminderId);
  }

  async cancelReminder(reminderId: string): Promise<boolean> {
    // 停止闹铃震动
    this.stopAlarmVibration(reminderId);

    const timerId = this.reminderTimers.get(reminderId);
    if (timerId) {
      clearTimeout(timerId);
      this.reminderTimers.delete(reminderId);
    }

    if (!this.activeReminders.has(reminderId)) {
      return false;
    }

    this.activeReminders.delete(reminderId);
    console.info('[StrongReminderService] Cancelled: ' + reminderId);
    return true;
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
    // 停止闹铃震动
    this.stopAlarmVibration(reminderId);

    if (this.reminderStore) {
      await this.reminderStore.updateStatus(reminderId, ReminderStatus.TAKEN);
    }

    await this.cancelReminder(reminderId + '_retry');
    console.info('[StrongReminderService] Confirmed taken: ' + reminderId);
  }

  async stopReminderAction(reminderId: string): Promise<void> {
    // 停止闹铃震动
    this.stopAlarmVibration(reminderId);

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

    const reminderId = Date.now();
    this.activeReminders.set(reminder.id + '_retry', reminderId);

    if (this.reminderStore) {
      await this.reminderStore.incrementRetry(reminder.id);
    }
    console.info('[StrongReminderService] Scheduled retry #' + (retryCount + 1));
  }

  async destroy(): Promise<void> {
    // 停止所有闹铃震动
    this.isVibrating = false;
    for (const intervalId of this.activeAlarmVibrations.values()) {
      clearInterval(intervalId);
    }
    this.activeAlarmVibrations.clear();
    try {
      vibrator.stop(vibrator.VibratorStopMode.VIBRATOR_STOP_MODE_TIME);
    } catch (e) {
      // 忽略
    }

    // 清理所有定时器
    for (const timerId of this.reminderTimers.values()) {
      clearTimeout(timerId);
    }
    this.reminderTimers.clear();
    this.activeReminders.clear();

    // 停止后台任务
    await this.stopBackgroundTask();

    console.info('[StrongReminderService] Destroyed');
  }
}

export const strongReminderService = new StrongReminderService();