/**
 * 药品库云端同步服务
 * 负责版本检测和增量更新
 */

import http from '@ohos.net.http';
import preference from '@ohos.data.preferences';
import common from '@ohos.app.ability.common';
import { MedicineLoader, MedicineInfo } from './MedicineLoader';

export interface CheckUpdateResult {
  hasUpdate: boolean;
  latestVersion: string;
  error?: string;
}

export interface SyncResult {
  success: boolean;
  updated: boolean;
  newVersion?: string;
  addedCount: number;
  updatedCount: number;
  deletedCount: number;
  error?: string;
}

export interface IncrementalUpdate {
  version: string;
  baseVersion: string;
  timestamp: string;
  added: MedicineInfo[];
  updated: MedicineInfo[];
  deleted: string[];
  asrCorrections?: Record<string, string>;
}

export interface VersionInfo {
  version: string;
  incrementalUrl?: string;
  checksum?: string;
}

/**
 * 药品库同步服务
 * 单例模式，支持版本检测和增量更新
 */
export class MedicineSyncService {
  private static instance: MedicineSyncService;

  // 配置
  private serverUrl: string = 'https://pua-skill.pages.dev/medicine';
  private preferences: preference.Preferences | null = null;
  private context: common.Context | null = null;

  // 状态
  private syncing: boolean = false;
  private lastSyncTime: string = '';

  // 回调
  private onProgressCallback?: (progress: number, message: string) => void;

  private constructor() {}

  static getInstance(): MedicineSyncService {
    if (!MedicineSyncService.instance) {
      MedicineSyncService.instance = new MedicineSyncService();
    }
    return MedicineSyncService.instance;
  }

  /**
   * 初始化服务
   */
  async init(context: common.Context): Promise<void> {
    this.context = context;
    try {
      this.preferences = await preference.getPreferences(context, 'medicine_sync');
      this.lastSyncTime = await this.preferences.get('lastSyncTime', '') as string;
      console.info('[MedicineSync] Initialized, lastSyncTime=' + this.lastSyncTime);
    } catch (e) {
      console.error('[MedicineSync] Init failed: ' + (e as Error).message);
    }
  }

  /**
   * 设置进度回调
   */
  setOnProgress(callback: (progress: number, message: string) => void): void {
    this.onProgressCallback = callback;
  }

  /**
   * 设置服务器地址
   */
  setServerUrl(url: string): void {
    this.serverUrl = url;
  }

  /**
   * 检查是否有更新
   */
  async checkUpdate(): Promise<CheckUpdateResult> {
    try {
      this.reportProgress(10, '检查版本...');

      const localVersion = await this.getLocalVersion();
      const serverVersion = await this.fetchServerVersion();

      console.info('[MedicineSync] Local: ' + localVersion + ', Server: ' + serverVersion.version);

      const result: CheckUpdateResult = {
        hasUpdate: serverVersion.version !== localVersion,
        latestVersion: serverVersion.version
      };
      return result;
    } catch (e) {
      console.error('[MedicineSync] checkUpdate failed: ' + (e as Error).message);
      const result: CheckUpdateResult = {
        hasUpdate: false,
        latestVersion: await this.getLocalVersion(),
        error: (e as Error).message
      };
      return result;
    }
  }

  /**
   * 执行同步
   */
  async sync(): Promise<SyncResult> {
    if (this.syncing) {
      return { success: false, updated: false, addedCount: 0, updatedCount: 0, deletedCount: 0, error: 'Already syncing' };
    }

    this.syncing = true;
    console.info('[MedicineSync] Starting sync...');

    try {
      // 1. 检查版本
      this.reportProgress(10, '检查版本...');
      const checkResult = await this.checkUpdate();

      if (!checkResult.hasUpdate) {
        this.syncing = false;
        this.reportProgress(100, '已是最新版本');
        return { success: true, updated: false, addedCount: 0, updatedCount: 0, deletedCount: 0 };
      }

      // 2. 下载增量更新
      this.reportProgress(30, '下载更新...');
      const incremental = await this.downloadIncremental();

      if (!incremental) {
        this.syncing = false;
        return { success: false, updated: false, addedCount: 0, updatedCount: 0, deletedCount: 0, error: 'Download failed' };
      }

      // 3. 应用更新
      this.reportProgress(70, '应用更新...');
      await this.applyIncremental(incremental);

      // 4. 更新本地版本
      await this.updateLocalVersion(incremental.version);

      // 5. 更新同步时间
      this.lastSyncTime = new Date().toISOString();
      if (this.preferences) {
        await this.preferences.put('lastSyncTime', this.lastSyncTime);
        await this.preferences.flush();
      }

      this.syncing = false;
      this.reportProgress(100, '同步完成');

      return {
        success: true,
        updated: true,
        newVersion: incremental.version,
        addedCount: incremental.added?.length || 0,
        updatedCount: incremental.updated?.length || 0,
        deletedCount: incremental.deleted?.length || 0
      };
    } catch (e) {
      this.syncing = false;
      console.error('[MedicineSync] sync failed: ' + (e as Error).message);
      return {
        success: false,
        updated: false,
        addedCount: 0,
        updatedCount: 0,
        deletedCount: 0,
        error: (e as Error).message
      };
    }
  }

  /**
   * 获取本地版本
   */
  async getLocalVersion(): Promise<string> {
    if (this.preferences) {
      return await this.preferences.get('version', '2026.04.01') as string;
    }
    return '2026.04.01';
  }

  /**
   * 获取上次同步时间
   */
  getLastSyncTime(): string {
    return this.lastSyncTime;
  }

  /**
   * 是否正在同步
   */
  isSyncing(): boolean {
    return this.syncing;
  }

  /**
   * 获取服务器版本信息
   */
  private async fetchServerVersion(): Promise<VersionInfo> {
    const httpRequest = http.createHttp();

    try {
      const response = await httpRequest.request(this.serverUrl + '/version.json', {
        method: http.RequestMethod.GET,
        connectTimeout: 10000,
        readTimeout: 10000
      });

      if (response.responseCode === 200) {
        const data: VersionInfo = JSON.parse(response.result as string) as VersionInfo;
        httpRequest.destroy();
        return data;
      } else {
        throw new Error('HTTP ' + response.responseCode);
      }
    } catch (e) {
      httpRequest.destroy();
      throw new Error((e as Error).message);
    }
  }

  /**
   * 下载增量更新包
   */
  private async downloadIncremental(): Promise<IncrementalUpdate | null> {
    try {
      const versionInfo = await this.fetchServerVersion();

      if (!versionInfo.incrementalUrl) {
        // 没有增量 URL，返回空更新
        console.info('[MedicineSync] No incremental URL, skipping');
        return null;
      }

      const httpRequest = http.createHttp();

      try {
        const response = await httpRequest.request(versionInfo.incrementalUrl, {
          method: http.RequestMethod.GET,
          connectTimeout: 30000,
          readTimeout: 60000
        });

        if (response.responseCode === 200) {
          const data: IncrementalUpdate = JSON.parse(response.result as string) as IncrementalUpdate;
          httpRequest.destroy();
          console.info('[MedicineSync] Downloaded incremental: version=' + data.version);
          return data;
        } else {
          throw new Error('HTTP ' + response.responseCode);
        }
      } catch (e) {
        httpRequest.destroy();
        throw new Error((e as Error).message);
      }
    } catch (e) {
      console.error('[MedicineSync] downloadIncremental failed: ' + (e as Error).message);
      return null;
    }
  }

  /**
   * 应用增量更新
   */
  private async applyIncremental(data: IncrementalUpdate): Promise<void> {
    const loader = MedicineLoader.getInstance();

    // 获取现有药品列表
    const allMedicines = loader.getAllMedicines();
    const medicineMap = new Map<string, MedicineInfo>();
    for (const m of allMedicines) {
      medicineMap.set(m.name, m);
    }

    // 处理删除
    if (data.deleted && data.deleted.length > 0) {
      for (const name of data.deleted) {
        medicineMap.delete(name);
      }
      console.info('[MedicineSync] Deleted ' + data.deleted.length + ' medicines');
    }

    // 处理更新
    if (data.updated && data.updated.length > 0) {
      for (const m of data.updated) {
        if (m.pinyin && !m.pinyinInitials) {
          m.pinyinInitials = loader.generatePinyinInitials(m.pinyin);
        }
        medicineMap.set(m.name, m);
      }
      console.info('[MedicineSync] Updated ' + data.updated.length + ' medicines');
    }

    // 处理新增
    if (data.added && data.added.length > 0) {
      for (const m of data.added) {
        if (m.pinyin && !m.pinyinInitials) {
          m.pinyinInitials = loader.generatePinyinInitials(m.pinyin);
        }
        medicineMap.set(m.name, m);
      }
      console.info('[MedicineSync] Added ' + data.added.length + ' medicines');
    }

    // 重建数据
    const updatedMedicines = Array.from(medicineMap.values());

    // 应用 ASR 纠错更新（如果有）
    // 注意：当前 MedicineLoader 不支持动态更新 ASR 映射
    // 这里只是日志记录
    if (data.asrCorrections) {
      console.info('[MedicineSync] ASR corrections: ' + Object.keys(data.asrCorrections).length + ' entries');
    }

    // 更新 Loader
    loader.setData(updatedMedicines);

    console.info('[MedicineSync] Applied incremental update: ' + data.version);
  }

  /**
   * 更新本地版本
   */
  private async updateLocalVersion(version: string): Promise<void> {
    if (this.preferences) {
      await this.preferences.put('version', version);
      await this.preferences.flush();
      console.info('[MedicineSync] Local version updated to ' + version);
    }
  }

  /**
   * 报告进度
   */
  private reportProgress(progress: number, message: string): void {
    console.info('[MedicineSync] Progress: ' + progress + '% - ' + message);
    if (this.onProgressCallback) {
      this.onProgressCallback(progress, message);
    }
  }
}