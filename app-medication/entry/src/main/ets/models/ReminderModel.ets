/**
 * 提醒数据模型
 * 用药提醒核心数据结构
 */

export interface MedicineReminder {
  id: string;
  time: string;              // 提醒时间 HH:mm
  medicineName: string;      // 药品名称
  medicineImage?: string;    // 药品图片路径（拍照后存储）
  dosage: string;            // 剂量
  frequency: ReminderFrequency; // 提醒频率
  status: ReminderStatus;    // 提醒状态
  createdAt: number;         // 创建时间戳
  lastRemindedAt?: number;   // 上次提醒时间戳
  retryCount: number;        // 重提醒次数（最多3次）
}

export enum ReminderFrequency {
  DAILY = 'daily',           // 每天
  EVERY_OTHER_DAY = 'every_other_day', // 隔天
  WEEKLY = 'weekly'          // 每周X
}

export enum ReminderStatus {
  PENDING = 'pending',       // 未提醒
  REMINDED = 'reminded',     // 已提醒（待确认）
  TAKEN = 'taken',           // 已服药
  SKIPPED = 'skipped'        // 已跳过
}

export interface MedicineInfo {
  name: string;
  specification: string;     // 规格
  usage: string;             // 用法
}

/**
 * 时间选择模型
 * 小时 (0-23) + 分钟 (00/30)
 */
export interface TimeSlot {
  hour: number;              // 0-23
  minute: number;            // 0 或 30
}

export function formatTimeSlot(slot: TimeSlot): string {
  const hourStr = slot.hour.toString().padStart(2, '0');
  const minStr = slot.minute.toString().padStart(2, '0');
  return `${hourStr}:${minStr}`;
}

export function parseTimeSlot(timeStr: string): TimeSlot {
  const parts = timeStr.split(':');
  return {
    hour: parseInt(parts[0], 10),
    minute: parseInt(parts[1], 10)
  };
}

/**
 * 生成唯一ID
 */
export function generateReminderId(): string {
  return `reminder_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;
}