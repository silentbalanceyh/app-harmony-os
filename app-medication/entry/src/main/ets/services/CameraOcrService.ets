/**
 * 拍照识别服务
 * 相机拍照 + OCR识别药盒（简化实现）
 */

import common from '@ohos.app.ability.common';
import fs from '@ohos.file.fs';
import { MedicineInfo } from '../models/ReminderModel';

const PHOTO_DIR = 'medication_photos';

export interface OcrResult {
  success: boolean;
  medicineInfo?: MedicineInfo;
  imagePath?: string;
  error?: string;
}

// 本地药品库接口
interface LocalMedicineEntry {
  key: string;
  info: MedicineInfo;
}

export class CameraOcrService {
  private context: common.UIAbilityContext | null = null;
  private photoPath: string = '';

  async init(context: common.UIAbilityContext): Promise<void> {
    this.context = context;
    this.photoPath = context.filesDir + '/' + PHOTO_DIR;
    try {
      fs.mkdirSync(this.photoPath);
    } catch (e) {
      // 目录已存在
    }
    console.info('[CameraOcrService] Initialized');
  }

  async captureAndRecognize(): Promise<OcrResult> {
    console.info('[CameraOcrService] Capture (stub)');
    return {
      success: false,
      error: '拍照识别功能即将上线'
    };
  }

  matchLocalMedicine(partialName: string): MedicineInfo | null {
    const commonMedicines: LocalMedicineEntry[] = [
      { key: '降压', info: { name: '降压药', specification: '10mg', usage: '口服' } },
      { key: '降糖', info: { name: '降糖药', specification: '5mg', usage: '口服' } },
      { key: '钙', info: { name: '钙片', specification: '500mg', usage: '口服' } },
      { key: '维', info: { name: '维生素', specification: '100mg', usage: '口服' } },
      { key: '胃', info: { name: '胃药', specification: '10mg', usage: '口服' } }
    ];

    for (const entry of commonMedicines) {
      if (partialName.includes(entry.key)) {
        return entry.info;
      }
    }
    return null;
  }

  async destroy(): Promise<void> {
    console.info('[CameraOcrService] Destroyed');
  }
}

export const cameraOcrService = new CameraOcrService();