/**
 * 拍照识别服务 - OCR 实现
 * 使用 HarmonyOS textRecognition API 提取药盒文字
 * 通过 MedicineDatabase 多策略匹配药品名称
 */

import common from '@ohos.app.ability.common';
import fs from '@ohos.file.fs';
import { MedicineDatabase } from './MedicineDatabase';
import { image } from '@kit.ImageKit';
import { textRecognition } from '@kit.CoreVisionKit';
import photoAccessHelper from '@ohos.file.photoAccessHelper';
import dataSharePredicates from '@ohos.data.dataSharePredicates';

const PHOTO_DIR = 'medication_photos';

export interface OcrResult {
  success: boolean;
  medicineName?: string;    // 匹配到的药品名称
  rawText?: string;         // OCR 原始文本
  candidates?: string[];    // 所有候选文本块
  imagePath?: string;
  confidence?: number;      // 匹配置信度 (1-5)
  error?: string;
}

export class CameraOcrService {
  private context: common.UIAbilityContext | null = null;
  private photoPath: string = '';
  private initialized: boolean = false;

  async init(context: common.UIAbilityContext): Promise<void> {
    console.info('[CameraOcrService] ========== INIT START ==========');
    this.context = context;
    this.photoPath = context.filesDir + '/' + PHOTO_DIR;
    console.info('[CameraOcrService] Context set, photoPath: ' + this.photoPath);

    try {
      fs.mkdirSync(this.photoPath);
      console.info('[CameraOcrService] Photo directory created');
    } catch (e) {
      console.info('[CameraOcrService] Photo directory already exists or creation failed');
    }

    // 初始化 OCR 服务
    try {
      console.info('[CameraOcrService] Calling textRecognition.init()...');
      const initResult: boolean = await textRecognition.init();
      this.initialized = initResult;
      console.info('[CameraOcrService] textRecognition.init() result: ' + initResult);

      if (!initResult) {
        console.warn('[CameraOcrService] textRecognition.init() returned false');
        console.warn('[CameraOcrService] This may indicate CoreVisionKit is not available on this device/emulator');
      }
    } catch (e) {
      const errMsg = this.formatError(e);
      console.warn('[CameraOcrService] textRecognition.init() threw exception: ' + errMsg);
      console.warn('[CameraOcrService] NOTE: HarmonyOS emulator may NOT support textRecognition API');
      console.warn('[CameraOcrService] NOTE: CoreVisionKit requires hardware ML acceleration');
      console.warn('[CameraOcrService] NOTE: Please test on a real HarmonyOS device');
      this.initialized = false;  // 明确标记初始化失败
    }

    console.info('[CameraOcrService] ========== INIT END (initialized=' + this.initialized + ') ==========');
  }

  /**
   * 对图片执行 OCR 识别并匹配药品名称
   * 流程：图片URI → HarmonyOS textRecognition → 文本提取 → 药品库匹配
   *
   * 注意：HarmonyOS 相册返回的 URI 格式为 file://media/Photo/...
   *       需要用 image.createImageSource(uri) 直接处理，不能用 fs.openSync
   */
  async recognizeFromUri(imageUri: string): Promise<OcrResult> {
    console.info('[CameraOcrService] ========== OCR DIAGNOSTIC START ==========');
    console.info('[CameraOcrService] Input URI: ' + imageUri);
    console.info('[CameraOcrService] Context status: ' + (this.context ? 'OK' : 'NULL'));
    console.info('[CameraOcrService] Initialized status: ' + this.initialized);

    if (!this.context) {
      console.error('[CameraOcrService] STEP FAIL: context is null');
      return { success: false, error: '服务未初始化' };
    }

    try {
      console.info('[CameraOcrService] STEP 1: Reading image file...');

      // 方案：PhotoPicker 返回的 URI 具有临时授权，直接用 fs.open() 打开
      let pixelMap: image.PixelMap | null = null;

      // STEP 1a: 直接尝试 fs.open() 打开媒体库 URI
      console.info('[CameraOcrService] STEP 1a: Trying fs.open() with URI...');
      try {
        const file = await fs.open(imageUri, fs.OpenMode.READ_ONLY);
        console.info('[CameraOcrService] STEP 1a: fs.open SUCCESS, fd=' + file.fd);

        // STEP 1b: 获取文件大小并读取内容
        const stat = fs.statSync(file.fd);
        console.info('[CameraOcrService] STEP 1b: File size=' + stat.size + ' bytes');

        const buffer = new ArrayBuffer(stat.size);
        fs.readSync(file.fd, buffer);
        fs.closeSync(file);
        console.info('[CameraOcrService] STEP 1b: File content read into buffer');

        // STEP 1c: 创建 ImageSource 和 PixelMap
        const imageSource = image.createImageSource(buffer);
        console.info('[CameraOcrService] STEP 1c: ImageSource created from buffer');

        const decodingOptions: image.DecodingOptions = {
          editable: false,
          desiredPixelFormat: image.PixelMapFormat.RGBA_8888
        };
        pixelMap = await imageSource.createPixelMap(decodingOptions);
        console.info('[CameraOcrService] STEP 1c: SUCCESS - PixelMap created');
      } catch (fsErr) {
        console.error('[CameraOcrService] STEP 1a fs.open FAILED: ' + this.formatError(fsErr));
        console.info('[CameraOcrService] STEP 1a-fallback: Trying photoAccessHelper approach...');

        // 回退方案：通过 photoAccessHelper 获取 PhotoAsset
        try {
          const phAccessHelper = photoAccessHelper.getPhotoAccessHelper(this.context);
          console.info('[CameraOcrService] STEP 1a-fallback: photoAccessHelper instance obtained');

          const predicates = new dataSharePredicates.DataSharePredicates();
          predicates.equalTo(photoAccessHelper.PhotoKeys.URI, imageUri);

          const fetchOptions: photoAccessHelper.FetchOptions = {
            fetchColumns: [photoAccessHelper.PhotoKeys.URI, photoAccessHelper.PhotoKeys.TITLE],
            predicates: predicates
          };
          console.info('[CameraOcrService] STEP 1a-fallback: FetchOptions created');

          const fetchResult = await phAccessHelper.getAssets(fetchOptions);
          const photoAsset = await fetchResult.getFirstObject();

          if (!photoAsset) {
            console.error('[CameraOcrService] STEP 1a-fallback: No PhotoAsset found');
          } else {
            console.info('[CameraOcrService] STEP 1a-fallback: PhotoAsset obtained');

            // 尝试 getReadOnlyFd
            const fd = await photoAsset.getReadOnlyFd();
            console.info('[CameraOcrService] STEP 1a-fallback: fd=' + fd);

            const stat = fs.statSync(fd);
            const buffer = new ArrayBuffer(stat.size);
            fs.readSync(fd, buffer);
            await photoAsset.close(fd);

            const imageSource = image.createImageSource(buffer);
            const decodingOptions: image.DecodingOptions = {
              editable: false,
              desiredPixelFormat: image.PixelMapFormat.RGBA_8888
            };
            pixelMap = await imageSource.createPixelMap(decodingOptions);
            console.info('[CameraOcrService] STEP 1a-fallback: SUCCESS - PixelMap created');
          }
        } catch (fallbackErr) {
          console.error('[CameraOcrService] STEP 1a-fallback FAILED: ' + this.formatError(fallbackErr));
        }
      }

      if (!pixelMap) {
        console.error('[CameraOcrService] STEP 2 FAIL: Unable to create PixelMap');
        return { success: false, error: '无法读取图片文件（请确认图片存在）' };
      }

      // 3. 使用 HarmonyOS textRecognition API 识别文字
      console.info('[CameraOcrService] STEP 3: Preparing VisionInfo...');
      const visionInfo: textRecognition.VisionInfo = {
        pixelMap: pixelMap
      };

      console.info('[CameraOcrService] STEP 3a: Calling textRecognition.recognizeText...');
      console.info('[CameraOcrService] STEP 3a: This may take a few seconds...');

      let recognitionResult: textRecognition.TextRecognitionResult;
      try {
        recognitionResult = await textRecognition.recognizeText(visionInfo);
        console.info('[CameraOcrService] STEP 3a: SUCCESS - recognizeText returned');
      } catch (ocrErr) {
        console.error('[CameraOcrService] STEP 3a FAILED: textRecognition.recognizeText error');
        console.error('[CameraOcrService] Error details: ' + this.formatError(ocrErr));
        // Check if this is an emulator limitation
        console.error('[CameraOcrService] NOTE: textRecognition API may not be supported on HarmonyOS emulator');
        console.error('[CameraOcrService] NOTE: Please test on a real device if possible');
        pixelMap.release();
        return {
          success: false,
          error: 'OCR服务不可用（模拟器可能不支持CoreVisionKit）',
          rawText: ''
        };
      }

      // 4. 提取所有文本块
      const candidates: string[] = [];
      let rawText = '';

      // 使用正确的结构：result.blocks（不是 textBlocks），block.value（不是 block.text）
      if (recognitionResult && recognitionResult.blocks) {
        for (const block of recognitionResult.blocks) {
          const blockText: string = block.value || '';
          if (blockText.trim().length > 0) {
            candidates.push(blockText.trim());
            rawText += blockText.trim() + '\n';
          }

          // 同时提取每行的文本
          if (block.lines) {
            for (const line of block.lines) {
              const lineText: string = line.value || '';
              if (lineText.trim().length > 0 && !candidates.includes(lineText.trim())) {
                candidates.push(lineText.trim());
              }
            }
          }
        }
      }

      // 同时获取完整识别文本
      if (recognitionResult.value) {
        rawText = recognitionResult.value;
      }

      // 释放资源
      pixelMap.release();

      console.info('[CameraOcrService] STEP 4: OCR extracted ' + candidates.length + ' text blocks');
      console.info('[CameraOcrService] STEP 4: Raw text preview: ' + rawText.substring(0, 200));

      if (candidates.length === 0) {
        console.warn('[CameraOcrService] STEP 4: No text extracted from image');
        return {
          success: false,
          rawText: rawText,
          error: '未能识别到文字，请重新拍照（图片可能模糊或光线不足）'
        };
      }

      // 5. 文本预处理：拆分和清洗候选文本
      console.info('[CameraOcrService] STEP 5: Preprocessing OCR text...');
      const cleanedCandidates = this.preprocessOcrText(candidates);
      console.info('[CameraOcrService] STEP 5: Cleaned candidates count: ' + cleanedCandidates.length);
      console.info('[CameraOcrService] STEP 5: Cleaned candidates: ' + JSON.stringify(cleanedCandidates.slice(0, 10)));

      // 6. 使用 MedicineDatabase 多策略匹配
      console.info('[CameraOcrService] STEP 6: Matching against medicine database...');
      const matchResult = MedicineDatabase.matchMedicineFromCandidates(cleanedCandidates);

      if (matchResult) {
        console.info('[CameraOcrService] STEP 6: SUCCESS - Matched: ' + matchResult.medicineName +
          ' (confidence: ' + matchResult.confidence + ')');
        console.info('[CameraOcrService] ========== OCR DIAGNOSTIC END (SUCCESS) ==========');
        return {
          success: true,
          medicineName: matchResult.medicineName,
          rawText: rawText,
          candidates: cleanedCandidates,
          imagePath: imageUri,
          confidence: matchResult.confidence
        };
      }

      // 7. 匹配失败，返回原始文本供用户参考
      console.warn('[CameraOcrService] STEP 6: No medicine match found');
      console.warn('[CameraOcrService] ========== OCR DIAGNOSTIC END (NO MATCH) ==========');
      return {
        success: false,
        rawText: rawText,
        candidates: cleanedCandidates,
        error: '未匹配到药品，请手动输入或重新拍照'
      };

    } catch (e) {
      const errMsg = this.formatError(e);
      console.error('[CameraOcrService] ========== OCR DIAGNOSTIC END (ERROR) ==========');
      console.error('[CameraOcrService] Unexpected error: ' + errMsg);
      return {
        success: false,
        error: '识别失败: ' + errMsg
      };
    }
  }

  /**
   * 格式化错误对象，便于日志输出
   */
  private formatError(e: Object | string | number | undefined): string {
    if (e instanceof Error) {
      return e.message + ' (' + e.name + ')';
    }
    if (typeof e === 'object' && e !== null && e !== undefined) {
      try {
        return JSON.stringify(e);
      } catch {
        return '[Object]';
      }
    }
    return String(e);
  }

  /**
   * 文本预处理：清洗 OCR 结果中的噪声
   * 药盒上常见的干扰文字：规格、厂家、批号、有效期、广告语等
   */
  private preprocessOcrText(candidates: string[]): string[] {
    const cleaned: string[] = [];

    // 需要过滤的噪声模式
    const noisePatterns: RegExp[] = [
      /\d{4}[\/\-]\d{2}[\/\-]\d{2}/,       // 日期格式 2025/01/01
      /\d{4}年\d{1,2}月\d{1,2}日/,          // 中文日期
      /有效期至?/,                           // 有效期
      /生产日期/,                            // 生产日期
      /批号/,                                // 批号
      /批准文号/,                            // 批准文号
      /^国药准字/,                           // 国药准字开头（不是药品名）
      /^\d{6,}$/ ,                          // 纯数字（批号等）
      /^[A-Z]\d{10,}$/ ,                    // 批准文号格式
      /贮存|储藏|贮藏/,                      // 贮存条件
      /说明书/,                              // 说明书
      /咨询|电话|热线/,                      // 联系方式
      /http|www|\.com|\.cn/,                // 网址
      /^[\d\s]+$/ ,                         // 纯数字+空格
    ];

    // 规格信息（保留但降低优先级，药品名可能和规格在一起）
    const specPatterns: RegExp[] = [
      /(\d+(\.\d+)?)(mg|g|ml|克|毫克|毫升)/,  // 规格：10mg, 0.5g
      /×\d+/,                                   // ×12片
      /\d+(片|粒|颗|袋|支|丸|贴)/,              // 数量：12片
    ];

    for (const text of candidates) {
      const trimmed = text.trim();
      if (trimmed.length < 2) continue;  // 过滤单个字符

      // 检查是否匹配噪声模式
      let isNoise = false;
      for (const pattern of noisePatterns) {
        if (pattern.test(trimmed)) {
          isNoise = true;
          break;
        }
      }

      if (isNoise) {
        console.info('[CameraOcrService] Filtered noise: ' + trimmed);
        continue;
      }

      // 清理文本中的特殊字符
      let cleanedText = trimmed
        .replace(/[^\u4e00-\u9fa5a-zA-Z0-9片颗粒袋包勺支丸滴个瓶胶囊口服液]/g, '')
        .trim();

      if (cleanedText.length >= 2) {
        cleaned.push(cleanedText);
      }

      // 对包含"规格+药品名"的文本进行拆分
      // 例如："阿莫西林胶囊0.5g×12片/盒" → "阿莫西林胶囊"
      for (const specPat of specPatterns) {
        const specMatch = trimmed.match(specPat);
        if (specMatch && specMatch.index !== undefined && specMatch.index > 2) {
          const beforeSpec = trimmed.substring(0, specMatch.index).trim();
          if (beforeSpec.length >= 2) {
            const cleanedBefore = beforeSpec
              .replace(/[^\u4e00-\u9fa5a-zA-Z0-9片颗粒袋包勺支丸滴个瓶胶囊口服液]/g, '')
              .trim();
            if (cleanedBefore.length >= 2 && !cleaned.includes(cleanedBefore)) {
              cleaned.push(cleanedBefore);
            }
          }
        }
      }
    }

    // 补充：将所有文本拼接后按常见分隔符拆分，增加匹配机会
    const allText = candidates.join('');
    const splitParts = allText.split(/[\s,，。、：:；;\n]+/);
    for (const part of splitParts) {
      const p = part.trim()
        .replace(/[^\u4e00-\u9fa5a-zA-Z0-9片颗粒袋包勺支丸滴个瓶胶囊口服液]/g, '')
        .trim();
      if (p.length >= 2 && !cleaned.includes(p)) {
        cleaned.push(p);
      }
    }

    return cleaned;
  }

  async destroy(): Promise<void> {
    // 释放 OCR 服务
    if (this.initialized) {
      try {
        await textRecognition.release();
        console.info('[CameraOcrService] OCR released');
      } catch (e) {
        console.warn('[CameraOcrService] OCR release failed: ' + JSON.stringify(e));
      }
    }
    console.info('[CameraOcrService] Destroyed');
  }
}

export const cameraOcrService = new CameraOcrService();