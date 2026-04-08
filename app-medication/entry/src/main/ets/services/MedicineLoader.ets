/**
 * 药品数据加载服务
 * 负责从 rawfile 加载药品数据 JSON 文件
 */

import resourceManager from '@ohos.resourceManager';
import common from '@ohos.app.ability.common';
import util from '@ohos.util';

export interface MedicineInfo {
  id?: string;
  name: string;
  aliases: string[];
  pinyin: string;
  pinyinInitials?: string;
  category: string;
  commonDosageForms: string[];
}

export interface MedicineData {
  version: string;
  totalCount: number;
  medicines: MedicineInfo[];
  asrCorrections?: Record<string, string>;
  charToInitial?: Record<string, string>;
  homophoneMap?: Record<string, string[]>;
}

export interface IncrementalUpdateInfo {
  version: string;
  url: string;
  checksum: string;
}

export interface MedicineVersionInfo {
  localVersion: string;
  serverVersion: string;
  lastSyncTime: string;
  incrementalUpdates: IncrementalUpdateInfo[];
}

/**
 * 药品数据加载器
 * 单例模式，支持从 rawfile 加载 JSON 数据
 */
export class MedicineLoader {
  private static instance: MedicineLoader;

  // 数据存储
  private medicineMap: Map<string, MedicineInfo> = new Map();
  private asrCorrectionMap: Map<string, string> = new Map();
  private charToInitialMap: Map<string, string> = new Map();
  private homophoneMap: Map<string, string[]> = new Map();

  // 状态
  private loaded: boolean = false;
  private loading: boolean = false;
  private version: string = '2026.04.01';

  private constructor() {}

  static getInstance(): MedicineLoader {
    if (!MedicineLoader.instance) {
      MedicineLoader.instance = new MedicineLoader();
    }
    return MedicineLoader.instance;
  }

  /**
   * 是否已加载
   */
  isLoaded(): boolean {
    return this.loaded;
  }

  /**
   * 获取版本号
   */
  getVersion(): string {
    return this.version;
  }

  /**
   * 加载本地药品数据
   * 优先级：增量数据 > rawfile 基础数据
   */
  async load(context: common.Context): Promise<void> {
    if (this.loaded || this.loading) {
      console.info('[MedicineLoader] Already loaded or loading, skip');
      return;
    }

    this.loading = true;
    console.info('[MedicineLoader] Starting load...');

    try {
      // 尝试从 rawfile 加载基础数据
      const loaded = await this.loadFromRawFile(context);

      if (loaded) {
        this.loaded = true;
        console.info('[MedicineLoader] Loaded ' + this.medicineMap.size + ' medicines from rawfile');
      } else {
        console.warn('[MedicineLoader] Failed to load from rawfile, will use built-in data');
        // 加载失败时，MedicineDatabase 会使用内置数据
      }
    } catch (e) {
      console.error('[MedicineLoader] Load failed: ' + (e as Error).message);
    } finally {
      this.loading = false;
    }
  }

  /**
   * 从 rawfile 加载基础数据
   */
  private async loadFromRawFile(context: common.Context): Promise<boolean> {
    try {
      const resMgr = context.resourceManager;

      // 检查文件是否存在
      try {
        await resMgr.getRawFile('medicine_base.json');
      } catch (e) {
        console.info('[MedicineLoader] medicine_base.json not found in rawfile');
        return false;
      }

      // 读取文件内容
      const fileData = await resMgr.getRawFileContent('medicine_base.json');
      const uint8Array = new Uint8Array(fileData);

      // 使用 util.TextDecoder 正确解码 UTF-8（修复中文乱码问题）
      const decoder = util.TextDecoder.create('utf-8');
      const text = decoder.decodeToString(uint8Array);

      // 解析 JSON
      const data: MedicineData = JSON.parse(text);
      console.info('[MedicineLoader] Parsed JSON: version=' + data.version + ', count=' + data.totalCount);

      // 加载药品数据
      this.loadMedicineData(data);

      return true;
    } catch (e) {
      console.error('[MedicineLoader] loadFromRawFile error: ' + (e as Error).message);
      return false;
    }
  }

  /**
   * 加载药品数据到内存
   */
  private loadMedicineData(data: MedicineData): void {
    // 设置版本
    this.version = data.version;

    // 清空现有数据
    this.medicineMap.clear();
    this.asrCorrectionMap.clear();
    this.charToInitialMap.clear();
    this.homophoneMap.clear();

    // 加载药品
    for (const m of data.medicines) {
      // 生成拼音首字母
      if (!m.pinyinInitials && m.pinyin) {
        m.pinyinInitials = this.generatePinyinInitials(m.pinyin);
      }

      // 主名称索引
      this.medicineMap.set(m.name, m);

      // 别名索引
      for (const alias of (m.aliases || [])) {
        if (!this.medicineMap.has(alias)) {
          this.medicineMap.set(alias, m);
        }
      }
    }

    // 加载 ASR 纠错映射
    if (data.asrCorrections) {
      const entries = Object.entries(data.asrCorrections);
      for (let i = 0; i < entries.length; i++) {
        const key = entries[i][0];
        const value = entries[i][1];
        this.asrCorrectionMap.set(key.toLowerCase(), value);
      }
    }

    // 加载汉字到拼音首字母映射
    if (data.charToInitial) {
      const entries = Object.entries(data.charToInitial);
      for (let i = 0; i < entries.length; i++) {
        const key = entries[i][0];
        const value = entries[i][1];
        this.charToInitialMap.set(key, value);
      }
    }

    // 加载同音字映射
    if (data.homophoneMap) {
      const entries = Object.entries(data.homophoneMap);
      for (let i = 0; i < entries.length; i++) {
        const key = entries[i][0];
        const value = entries[i][1];
        this.homophoneMap.set(key, value);
      }
    }

    console.info('[MedicineLoader] Data loaded: medicines=' + this.medicineMap.size +
      ', asrCorrections=' + this.asrCorrectionMap.size +
      ', charToInitial=' + this.charToInitialMap.size +
      ', homophones=' + this.homophoneMap.size);
  }

  /**
   * 手动设置数据（用于内置数据加载）
   */
  setData(medicines: MedicineInfo[], asrCorrections?: Map<string, string>,
          charToInitial?: Map<string, string>, homophones?: Map<string, string[]>): void {
    // 清空现有数据
    this.medicineMap.clear();
    this.asrCorrectionMap.clear();
    this.charToInitialMap.clear();
    this.homophoneMap.clear();

    // 加载药品
    for (const m of medicines) {
      this.medicineMap.set(m.name, m);
      for (const alias of (m.aliases || [])) {
        if (!this.medicineMap.has(alias)) {
          this.medicineMap.set(alias, m);
        }
      }
    }

    // 加载映射
    if (asrCorrections) {
      this.asrCorrectionMap = asrCorrections;
    }
    if (charToInitial) {
      this.charToInitialMap = charToInitial;
    }
    if (homophones) {
      this.homophoneMap = homophones;
    }

    this.loaded = true;
    console.info('[MedicineLoader] Built-in data set: ' + this.medicineMap.size + ' medicines');
  }

  /**
   * 查询药品
   */
  getMedicine(name: string): MedicineInfo | undefined {
    return this.medicineMap.get(name);
  }

  /**
   * ASR 纠错
   */
  correctAsr(text: string): string | undefined {
    const normalized = text.toLowerCase().replace(/\s/g, '');
    return this.asrCorrectionMap.get(normalized);
  }

  /**
   * 获取汉字的拼音首字母
   */
  getCharInitial(char: string): string | undefined {
    return this.charToInitialMap.get(char);
  }

  /**
   * 获取同音字列表
   */
  getHomophones(char: string): string[] | undefined {
    return this.homophoneMap.get(char);
  }

  /**
   * 获取所有药品（用于遍历匹配）
   */
  getAllMedicines(): MedicineInfo[] {
    const set = new Set<MedicineInfo>();
    for (const m of this.medicineMap.values()) {
      set.add(m);
    }
    return Array.from(set);
  }

  /**
   * 获取 ASR 纠错映射大小
   */
  getAsrCorrectionSize(): number {
    return this.asrCorrectionMap.size;
  }

  /**
   * 从拼音字符串生成拼音首字母
   * 例如：mengtuoShisan → mtss
   */
  generatePinyinInitials(pinyin: string): string {
    const initials: string[] = [];
    const vowels = 'aeiouv';
    const lower = pinyin.toLowerCase();
    let i = 0;

    while (i < lower.length) {
      if (!/[a-z]/.test(lower[i])) {
        i++;
        continue;
      }

      initials.push(lower[i]);

      // 跳过辅音
      while (i < lower.length && !vowels.includes(lower[i])) {
        i++;
      }

      // 跳过元音
      while (i < lower.length && vowels.includes(lower[i])) {
        i++;
      }

      // 跳过鼻音
      if (i < lower.length && lower[i] === 'n') {
        i++;
        if (i < lower.length && lower[i] === 'g') {
          i++;
        }
      }
    }

    return initials.join('');
  }

  /**
   * 从汉字文本提取拼音首字母
   */
  getInitialsFromText(text: string): string {
    const initials: string[] = [];
    for (const char of text) {
      const initial = this.charToInitialMap.get(char);
      if (initial) {
        initials.push(initial);
      }
    }
    return initials.join('');
  }
}