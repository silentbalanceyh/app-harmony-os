/**
 * 语音交互服务
 * 使用 @hms.ai.speechRecognizer 和 @hms.ai.textToSpeech
 *
 * REQ0.2 优化：
 * - 播报结束播放"滴"提示音
 * - VAD 参数调优（前端点 600ms，后端点 1000ms）
 * - 录音头部缓冲 200ms
 */

import common from '@ohos.app.ability.common';
import speechRecognizer from '@hms.ai.speechRecognizer';
import textToSpeech from '@hms.ai.textToSpeech';
import audio from '@ohos.multimedia.audio';
import abilityAccessCtrl, { Permissions } from '@ohos.abilityAccessCtrl';
import { ReminderStore } from './ReminderStore';
import { formatTimeSlot } from '../models/ReminderModel';
import { MedicineDatabase } from './MedicineDatabase';
import SoundEffectPlayer from '../utils/SoundEffectPlayer';

const WAKEUP_WORD = '小药小药';

// VAD 参数配置
// vadBegin: 检测到静音后等待语音开始的超时时间
// vadEnd: 检测到语音结束后静音多久认为说话结束
const VAD_BEGIN_MS = 5000;    // 前端点：5秒（等待用户开始说话）
const VAD_END_MS = 1500;      // 后端点：1.5秒（说完后等待时间）
const RECORD_HEAD_BUFFER_MS = 200;

export interface VoiceResult {
  success: boolean;
  text?: string;           // 解析后的文本（用于药品名）
  rawText?: string;        // 原始识别文本（用于频率、剂量解析）
  medicineName?: string;
  time?: string;
  dosage?: string;
  frequency?: string;
  error?: string;
}

export class VoiceService {
  private context: common.UIAbilityContext | null = null;
  private reminderStore: ReminderStore | null = null;
  private onWakeupCallback: (() => void) | null = null;

  // 语音识别引擎
  private asrEngine: speechRecognizer.SpeechRecognitionEngine | null = null;
  // 语音合成引擎
  private ttsEngine: textToSpeech.TextToSpeechEngine | null = null;
  // 提示音播放器（使用 SoundEffectPlayer，REQ0.2）
  private beepPlayer: SoundEffectPlayer | null = null;

  private isListening: boolean = false;
  private sessionId: string = '';
  private currentCapturer: audio.AudioCapturer | null = null;  // 跟踪当前音频采集器
  private lastSessionId: string = '';  // 追踪上一个完成的会话ID，忽略过期回调

  /**
   * 初始化语音服务
   */
  async init(
    context: common.UIAbilityContext,
    store: ReminderStore,
    onWakeup?: () => void
  ): Promise<void> {
    this.context = context;
    this.reminderStore = store;
    if (onWakeup !== undefined) {
      this.onWakeupCallback = onWakeup;
    }

    try {
      // 初始化药品库（自动生成 ASR 纠错映射）
      MedicineDatabase.initialize();
      console.info('[VoiceService] Medicine database initialized');

      // 初始化语音识别引擎
      this.asrEngine = await speechRecognizer.createEngine({
        language: 'zh-CN',
        online: 1  // 离线模式
      });
      console.info('[VoiceService] ASR engine initialized');
    } catch (e) {
      console.error('[VoiceService] ASR init failed: ' + JSON.stringify(e));
    }

    try {
      // 初始化语音合成引擎
      this.ttsEngine = await textToSpeech.createEngine({
        language: 'zh-CN',
        person: 0,
        online: 1  // 离线模式
      });
      console.info('[VoiceService] TTS engine initialized');
    } catch (e) {
      console.error('[VoiceService] TTS init failed (may not support on emulator): ' + JSON.stringify(e));
      // TTS 初始化失败不阻止整个服务，只是语音播报不可用
    }

    // 初始化提示音播放器（REQ0.2）
    this.beepPlayer = new SoundEffectPlayer();
    console.info('[VoiceService] Beep player initialized');
  }

  /**
   * 播放提示音"滴"（REQ0.2）
   * 在播报结束后立即播放，告知用户可以说话
   */
  async playBeep(): Promise<void> {
    if (!this.beepPlayer || !this.context) {
      console.warn('[VoiceService] Beep player not available');
      return;
    }

    try {
      await this.beepPlayer.play(this.context, 'beep.wav');
      console.info('[VoiceService] Beep played');
    } catch (e) {
      console.error('[VoiceService] Play beep failed: ' + JSON.stringify(e));
    }
  }

  /**
   * 语音播报（双重保险：基于文本长度计算最小播放时间 + onComplete事件）
   * 策略：确保至少等待"字数*250ms"的时间，无论onComplete何时触发
   */
  async speak(text: string): Promise<void> {
    if (!this.ttsEngine) {
      console.error('[VoiceService] TTS engine not initialized');
      // TTS不可用时按文本长度等待
      const waitTime = Math.max(2000, text.length * 300);
      return new Promise(resolve => setTimeout(resolve, waitTime));
    }

    return new Promise((resolve) => {
      const requestId = Date.now().toString();
      const startTime = Date.now();

      // 基于文本长度计算最小播放时间（每字250ms，最少2秒）
      const minDuration = Math.max(2000, text.length * 250);
      console.info('[VoiceService] TTS speak: "' + text + '" minDuration=' + minDuration + 'ms');

      let resolved = false;
      let timeoutId: number | undefined;

      // 超时保底：最小播放时间 + 5秒额外缓冲
      const FAILSAFE_TIMEOUT = minDuration + 5000;
      timeoutId = setTimeout(() => {
        if (!resolved) {
          resolved = true;
          console.warn('[VoiceService] TTS failsafe timeout after ' + FAILSAFE_TIMEOUT + 'ms');
          resolve();
        }
      }, FAILSAFE_TIMEOUT);

      // 设置监听器
      this.ttsEngine!.setListener({
        onStart: (reqId: string, response: textToSpeech.StartResponse) => {
          console.info('[VoiceService] TTS onStart: ' + reqId);
        },
        onComplete: (reqId: string, response: textToSpeech.CompleteResponse) => {
          if (!resolved && reqId === requestId) {
            const elapsed = Date.now() - startTime;
            console.info('[VoiceService] TTS onComplete after ' + elapsed + 'ms');

            // 关键：检查是否已达到最小播放时间
            if (elapsed < minDuration) {
              // onComplete提前触发，需要额外等待
              const remaining = minDuration - elapsed;
              console.info('[VoiceService] TTS need extra wait: ' + remaining + 'ms');
              clearTimeout(timeoutId!);
              setTimeout(() => {
                if (!resolved) {
                  resolved = true;
                  console.info('[VoiceService] TTS resolved after minDuration');
                  resolve();
                }
              }, remaining);
            } else {
              // 正常完成，额外缓冲500ms
              resolved = true;
              clearTimeout(timeoutId!);
              setTimeout(resolve, 500);
            }
          }
        },
        onStop: (reqId: string, response: textToSpeech.StopResponse) => {
          if (!resolved && reqId === requestId) {
            const elapsed = Date.now() - startTime;
            console.info('[VoiceService] TTS onStop after ' + elapsed + 'ms');
            if (elapsed < minDuration) {
              const remaining = minDuration - elapsed;
              clearTimeout(timeoutId!);
              setTimeout(() => {
                if (!resolved) {
                  resolved = true;
                  resolve();
                }
              }, remaining);
            } else {
              resolved = true;
              clearTimeout(timeoutId!);
              resolve();
            }
          }
        },
        onError: (reqId: string, errorCode: number, errorMessage: string) => {
          if (!resolved && reqId === requestId) {
            console.error('[VoiceService] TTS onError: ' + errorMessage);
            resolved = true;
            clearTimeout(timeoutId!);
            // 即使出错也等待最小时间
            const elapsed = Date.now() - startTime;
            const remaining = Math.max(0, minDuration - elapsed);
            setTimeout(resolve, remaining);
          }
        }
      });

      // 调用speak
      this.ttsEngine!.speak(text, {
        requestId: requestId,
        extraParams: {}
      });
    });
  }

  /**
   * 请求麦克风权限
   */
  private async requestMicrophonePermission(): Promise<boolean> {
    if (!this.context) {
      return false;
    }
    try {
      const atManager = abilityAccessCtrl.createAtManager();
      const tokenID = this.context.applicationInfo.accessTokenId;

      // 先检查是否已有权限
      const grantStatus = await atManager.verifyAccessToken(tokenID, 'ohos.permission.MICROPHONE');
      if (grantStatus === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
        console.info('[VoiceService] Microphone permission already granted');
        return true;
      }

      // 请求权限
      console.info('[VoiceService] Requesting microphone permission...');
      const result = await atManager.requestPermissionsFromUser(this.context, ['ohos.permission.MICROPHONE']);
      console.info('[VoiceService] Permission result: ' + JSON.stringify(result));

      if (result.authResults && result.authResults.length > 0 && result.authResults[0] === 0) {
        return true;
      }
      return false;
    } catch (e) {
      console.error('[VoiceService] Request microphone permission failed: ' + JSON.stringify(e));
      return false;
    }
  }

  /**
   * 开始语音识别
   * @param timeout 超时时间
   * @param parseMedicine 是否进行药品解析（Step 1问药品名时为true，其他步骤为false）
   */
  async startRecognition(timeout: number = 30000, parseMedicine: boolean = true): Promise<VoiceResult> {
    if (!this.asrEngine) {
      return { success: false, error: '语音引擎未初始化' };
    }

    if (this.isListening) {
      return { success: false, error: '正在识别中' };
    }

    // 请求麦克风权限
    const hasMicPermission = await this.requestMicrophonePermission();
    if (!hasMicPermission) {
      return { success: false, error: '需要麦克风权限才能语音识别' };
    }

    // 清理上一个会话的资源
    await this.cleanupCapturer();

    this.isListening = true;
    this.sessionId = Date.now().toString();
    console.info('[VoiceService] ========== startRecognition BEGIN ==========');
    console.info('[VoiceService] sessionId=' + this.sessionId + ', vadBegin=' + VAD_BEGIN_MS + 'ms, vadEnd=' + VAD_END_MS + 'ms, timeout=' + timeout + 'ms');

    const currentSessionId = this.sessionId;  // 闭包捕获当前会话ID

    return new Promise(async (resolve) => {
      let recognizedText: string = '';
      let resolved = false;  // 防止 onComplete 和 onError 竞态重复 resolve

      this.asrEngine!.setListener({
        onStart: (sessionId: string, eventMessage: string) => {
          if (sessionId !== currentSessionId) return;
          console.info('[VoiceService] Recognition started');
        },
        onEvent: (sessionId: string, eventCode: number, eventMessage: string) => {
          if (sessionId !== currentSessionId) return;
          console.info('[VoiceService] Event: ' + eventCode);
        },
        onResult: (sessionId: string, result: speechRecognizer.SpeechRecognitionResult) => {
          if (sessionId !== currentSessionId) return;
          if (result.result) {
            recognizedText = result.result;
            console.info('[VoiceService] Partial result: ' + result.result);
          }
        },
        onComplete: (sessionId: string, eventMessage: string) => {
          if (sessionId !== currentSessionId || resolved) return;
          resolved = true;  // 标记已处理，防止 onError 竞态
          console.info('[VoiceService] ========== Recognition COMPLETE ==========');
          console.info('[VoiceService] recognizedText="' + recognizedText + '", parseMedicine=' + parseMedicine);

          // 先停止音频采集，再处理结果
          this.cleanupCapturer().then(() => {
            this.isListening = false;
            this.lastSessionId = currentSessionId;

            if (recognizedText) {
              const candidates = [recognizedText];
              console.info('[VoiceService] Using single result with 5-level matching: ' + recognizedText);

              if (parseMedicine) {
                const parsed = this.parseVoiceCommandWithCandidates(candidates);
                resolve(parsed);
              } else {
                resolve({
                  success: true,
                  text: recognizedText,
                  rawText: recognizedText
                });
              }
            } else {
              resolve({ success: false, error: '没有识别到语音，请再说一遍' });
            }
          });
        },
        onError: (sessionId: string, errorCode: number, errorMessage: string) => {
          if (sessionId !== currentSessionId) return;
          if (resolved) {
            // onComplete 已经处理过了，这是清理后的残留错误，忽略
            console.warn('[VoiceService] ASR post-complete error: ' + errorMessage);
            return;
          }
          // 真正的错误（如超时、网络问题），onComplete 不会触发
          resolved = true;
          console.error('[VoiceService] Recognition error: ' + errorMessage);
          this.cleanupCapturer().then(() => {
            this.isListening = false;
            this.lastSessionId = currentSessionId;
            resolve({ success: false, error: '识别失败：' + errorMessage });
          });
        }
      });

      try {
        // 启动 ASR 引擎
        this.asrEngine!.startListening({
          sessionId: this.sessionId,
          audioInfo: {
            audioType: 'pcm',
            sampleRate: 16000,
            soundChannel: 1,
            sampleBit: 16
          },
          extraParams: {
            timeout: timeout,
            vadBegin: VAD_BEGIN_MS,
            vadEnd: VAD_END_MS,
            maxAudioDuration: 60000
          }
        });
        console.info('[VoiceService] ASR startListening: vadBegin=' + VAD_BEGIN_MS + 'ms, vadEnd=' + VAD_END_MS + 'ms');

        // 创建 AudioCapturer 采集麦克风音频
        const audioCapturerInfo: audio.AudioCapturerInfo = {
          source: audio.SourceType.SOURCE_TYPE_MIC,
          capturerFlags: 0
        };

        const audioStreamInfo: audio.AudioStreamInfo = {
          samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_16000,
          channels: audio.AudioChannel.CHANNEL_1,
          sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
          encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
        };

        const audioCapturerOptions: audio.AudioCapturerOptions = {
          streamInfo: audioStreamInfo,
          capturerInfo: audioCapturerInfo
        };

        this.currentCapturer = await audio.createAudioCapturer(audioCapturerOptions);
        console.info('[VoiceService] AudioCapturer created');

        // 监听音频数据
        this.currentCapturer.on('readData', (buffer: ArrayBuffer) => {
          // 使用类字段检查状态，避免引用过期的局部变量
          if (this.isListening && this.asrEngine && this.sessionId === currentSessionId) {
            try {
              const uint8Array = new Uint8Array(buffer);
              this.asrEngine.writeAudio(this.sessionId, uint8Array);
            } catch (writeErr) {
              // 静默忽略写入错误（会话可能已结束）
            }
          }
        });

        // 开始采集
        await this.currentCapturer.start();
        console.info('[VoiceService] AudioCapturer started');

      } catch (e) {
        this.isListening = false;
        console.error('[VoiceService] Start recognition failed: ' + JSON.stringify(e));
        resolve({ success: false, error: '启动识别失败: ' + JSON.stringify(e) });
      }
    });
  }

  /**
   * 安全清理音频采集器
   */
  private async cleanupCapturer(): Promise<void> {
    if (this.currentCapturer) {
      const capturer = this.currentCapturer;
      this.currentCapturer = null;  // 先置空，防止 readData 回调继续写入
      try {
        if (capturer.state === audio.AudioState.STATE_RUNNING ||
            capturer.state === audio.AudioState.STATE_PAUSED) {
          await capturer.stop();
        }
        await capturer.release();
        console.info('[VoiceService] AudioCapturer cleaned up');
      } catch (e) {
        // 静默处理清理错误
      }
    }
  }

  /**
   * 停止识别
   */
  async stopRecognition(): Promise<void> {
    if (!this.asrEngine || !this.isListening) {
      return;
    }

    try {
      this.asrEngine!.finish(this.sessionId);
    } catch (e) {
      console.error('[VoiceService] Stop recognition failed');
    }
  }

  /**
   * 清理识别文本中的提示语和重复词
   */
  private cleanRecognitionText(text: string): string {
    // 已知的 TTS 提示语，需要过滤掉
    const promptPhrases = [
      '请说药品名称', '请说药品', '请说药', '请说',
      '药品名称要比名称', '药品名称要比', '药品名称', '药品',
      '名称要比名称', '名称要比', '名称',
      '一天吃几次', '一次吃多少',
      '好的', '没听清', '请再说一遍',
      '并说', '并且说', '说', '是说'  // TTS 残响词
    ];

    let cleaned = text;
    for (const prompt of promptPhrases) {
      cleaned = cleaned.replace(new RegExp(prompt, 'g'), '');
    }

    // 使用药品库进行 ASR 纠错
    const corrected = MedicineDatabase.correctAsrResult(cleaned);
    if (corrected && corrected !== cleaned) {
      console.info('[VoiceService] ASR correction: ' + cleaned + ' -> ' + corrected);
      cleaned = corrected;
    }

    // 移除多余空格和标点
    cleaned = cleaned.replace(/[，。、！？\s]+/g, '').trim();

    return cleaned;
  }

  /**
   * 解析语音命令（使用多候选结果）
   */
  parseVoiceCommandWithCandidates(candidates: string[]): VoiceResult {
    if (!candidates || candidates.length === 0) {
      return { success: false, error: '没有识别到语音，请再说一遍' };
    }

    // 清理所有候选结果
    const cleanedCandidates = candidates.map(t => this.cleanRecognitionText(t)).filter(t => t.length > 0);
    console.info('[VoiceService] Cleaned candidates: ' + JSON.stringify(cleanedCandidates));

    // 检查是否有查询命令
    for (const text of cleanedCandidates) {
      const lowerText = text.toLowerCase();
      if (lowerText.includes('下次') || lowerText.includes('什么时候') || lowerText.includes('查询')) {
        return {
          success: true,
          text: '查询下次提醒',
          rawText: candidates[0]
        };
      }
    }

    // 使用多候选结果进行药品匹配
    const matchResult = MedicineDatabase.matchMedicineFromCandidates(cleanedCandidates);

    if (matchResult) {
      console.info('[VoiceService] Medicine matched: ' + matchResult.medicineName + ' (confidence=' + matchResult.confidence + ')');

      // 从第一个候选中提取时间和剂量
      const firstCleaned = cleanedCandidates[0];
      const timeMatch = this.extractTime(firstCleaned);
      const dosageMatch = this.extractDosage(firstCleaned);
      const frequencyMatch = this.extractFrequency(firstCleaned);

      return {
        success: true,
        text: firstCleaned,
        rawText: candidates[0],
        time: timeMatch || undefined,
        medicineName: matchResult.medicineName,
        dosage: dosageMatch || '1片',
        frequency: frequencyMatch || '每天'
      };
    }

    // 无法匹配药品，返回第一个候选作为药品名（保持原有行为）
    const firstCleaned = cleanedCandidates[0];
    console.info('[VoiceService] No medicine matched, using first candidate as medicine name: ' + firstCleaned);

    return {
      success: true,
      text: firstCleaned,
      rawText: candidates[0],
      medicineName: firstCleaned,
      dosage: '1片',
      frequency: '每天'
    };
  }

  /**
   * 解析语音命令
   */
  parseVoiceCommand(text: string): VoiceResult {
    // 先清理提示语
    const cleanedText = this.cleanRecognitionText(text);
    console.info('[VoiceService] Cleaned text: ' + cleanedText + ' (original: ' + text + ')');

    const lowerText = cleanedText.toLowerCase();

    // 查询命令
    if (lowerText.includes('下次') || lowerText.includes('什么时候') || lowerText.includes('查询')) {
      return {
        success: true,
        text: '查询下次提醒',
        rawText: text  // 保存原始识别文本
      };
    }

    // 设置提醒命令
    const timeMatch = this.extractTime(cleanedText);
    const medicineMatch = this.extractMedicine(cleanedText);
    const dosageMatch = this.extractDosage(cleanedText);
    const frequencyMatch = this.extractFrequency(cleanedText);

    if (medicineMatch) {
      return {
        success: true,
        text: cleanedText,
        rawText: text,  // 保存原始识别文本
        time: timeMatch || undefined,
        medicineName: medicineMatch,
        dosage: dosageMatch || '1片',
        frequency: frequencyMatch || '每天'
      };
    }

    // 如果清理后还有文本，直接作为药品名称
    if (cleanedText.length > 0) {
      return {
        success: true,
        text: cleanedText,
        rawText: text,  // 保存原始识别文本
        medicineName: cleanedText,
        dosage: '1片',
        frequency: '每天'
      };
    }

    return {
      success: false,
      text: text,
      rawText: text,  // 保存原始识别文本
      error: '请再说一遍药名和时间'
    };
  }

  /**
   * 提取时间
   */
  private extractTime(text: string): string | null {
    const patterns = [
      /(\d{1,2})点半/,
      /(\d{1,2})点(\d{1,2})?/,
      /早上(\d{1,2})/,
      /中午(\d{1,2})/,
      /下午(\d{1,2})/,
      /晚上(\d{1,2})/,
      /早晨(\d{1,2})/
    ];

    for (const pattern of patterns) {
      const match = text.match(pattern);
      if (match) {
        let hour = parseInt(match[1], 10);
        let minute = 0;

        if (text.includes('半')) {
          minute = 30;
        }

        if (text.includes('下午') || text.includes('晚上')) {
          if (hour < 12) {
            hour += 12;
          }
        }

        return formatTimeSlot({ hour, minute });
      }
    }

    return null;
  }

  /**
   * 提取药名（使用药品库智能匹配）
   */
  private extractMedicine(text: string): string | null {
    // 1. 使用药品库进行 ASR 纠错 + 药品匹配
    const medicineInfo = MedicineDatabase.extractMedicineName(text);
    if (medicineInfo) {
      // 检查药品名是否已包含剂型，避免重复（如"速效救心丸"+"丸"→"速效救心丸丸"）
      if (medicineInfo.dosageForm && medicineInfo.name.endsWith(medicineInfo.dosageForm)) {
        console.info('[MedicineDb] Matched (no duplicate suffix): ' + text + ' -> ' + medicineInfo.name);
        return medicineInfo.name;
      }
      const fullName = medicineInfo.dosageForm
        ? medicineInfo.name + medicineInfo.dosageForm
        : medicineInfo.name;
      console.info('[MedicineDb] Matched: ' + text + ' -> ' + fullName);
      return fullName;
    }

    // 2. 剂型后缀（用于提取完整药品名）
    const dosageForms = [
      '胶囊', '片', '颗粒', '口服液', '糖浆', '滴剂', '喷雾', '软膏', '眼药水',
      '缓释片', '控释片', '肠溶片', '分散片', '咀嚼片', '含片', '泡腾片',
      '缓释胶囊', '软胶囊', '硬胶囊', '注射液', '粉针剂', '丸', '散'
    ];

    // 3. 如果药品库未匹配，检查是否包含剂型结尾
    for (const form of dosageForms) {
      const match = text.match(new RegExp('(.{2,10})' + form));
      if (match) {
        return match[0];  // 返回完整名称
      }
    }

    // 4. 模糊搜索
    const searchResults = MedicineDatabase.searchMedicine(text);
    if (searchResults.length > 0) {
      console.info('[MedicineDb] Search found: ' + searchResults[0].name);
      return searchResults[0].name;
    }

    return null;
  }

  /**
   * 提取剂量
   */
  private extractDosage(text: string): string | null {
    // 支持多种剂量单位：片、颗、粒、袋、包、支、瓶、勺
    const patterns = [
      /半片/, /半颗/, /半粒/, /半瓶/,
      /一片/, /一颗粒/, /一袋/, /一包/, /一支/, /一瓶/, /一勺/,
      /两片/, /两颗/, /两粒/, /两袋/, /两包/, /两支/, /两瓶/, /两勺/,
      /三片/, /三颗/, /三粒/, /三袋/, /三包/, /三支/, /三瓶/, /三勺/,
      /四片/, /四颗/, /四粒/, /四袋/, /四包/, /四支/, /四瓶/, /四勺/,
      /五片/, /五颗/, /五粒/, /五袋/, /五包/, /五支/, /五瓶/, /五勺/,
      /(\d+)片/, /(\d+)颗/, /(\d+)粒/, /(\d+)袋/, /(\d+)包/, /(\d+)支/, /(\d+)瓶/, /(\d+)勺/,
      /(\d+)个/, /(\d+)丸/
    ];

    for (const pattern of patterns) {
      const match = text.match(pattern);
      if (match) {
        return match[0];
      }
    }

    return null;
  }

  /**
   * 提取频率
   */
  private extractFrequency(text: string): string | null {
    if (text.includes('每天') || text.includes('一日')) {
      return '每天';
    }
    if (text.includes('隔天') || text.includes('隔日')) {
      return '隔天';
    }
    if (text.includes('每周')) {
      return '每周';
    }
    return null;
  }

  /**
   * 语音设置提醒
   */
  async setReminderByVoice(result: VoiceResult): Promise<boolean> {
    if (!result.success || !result.time || !result.medicineName) {
      await this.speak('设置失败，请再说一遍药名和时间');
      return false;
    }

    try {
      if (this.reminderStore) {
        await this.reminderStore.addReminder(
          result.time,
          result.medicineName,
          result.dosage || '1片'
        );

        await this.speak('好的，已设置' + result.medicineName + '在' + result.time + '提醒，每次' + (result.dosage || '1片'));
        return true;
      }
    } catch (err) {
      console.error('[VoiceService] Set reminder failed: ' + JSON.stringify(err));
      await this.speak('设置提醒时出错了，请重试');
    }

    return false;
  }

  /**
   * 语音查询下次提醒
   */
  async queryNextReminder(): Promise<void> {
    if (!this.reminderStore) {
      await this.speak('查询失败，请稍后重试');
      return;
    }

    try {
      const reminders = await this.reminderStore.getTodayReminders();
      if (reminders.length === 0) {
        await this.speak('今天还没有提醒');
        return;
      }

      const now = new Date();
      const currentTime = now.getHours().toString().padStart(2, '0') + ':' +
                          now.getMinutes().toString().padStart(2, '0');

      const nextReminder = reminders.find(r => r.time > currentTime);
      if (nextReminder) {
        await this.speak('下次提醒是' + nextReminder.time + '，服用' + nextReminder.medicineName);
      } else {
        await this.speak('今天的提醒已全部完成');
      }
    } catch (err) {
      console.error('[VoiceService] Query failed: ' + JSON.stringify(err));
      await this.speak('查询失败，请稍后重试');
    }
  }

  /**
   * 开始唤醒监听（持续监听唤醒词）
   */
  async startWakeup(): Promise<void> {
    console.info('[VoiceService] Wakeup monitoring started');
    // 持续监听模式需要应用保持前台运行
    // 这里简化实现，实际使用时需要结合语音唤醒API
  }

  /**
   * 停止唤醒监听
   */
  async stopWakeup(): Promise<void> {
    console.info('[VoiceService] Wakeup monitoring stopped');
  }

  /**
   * 销毁服务
   */
  async destroy(): Promise<void> {
    if (this.asrEngine) {
      this.asrEngine.shutdown();
      this.asrEngine = null;
    }
    if (this.ttsEngine) {
      this.ttsEngine.shutdown();
      this.ttsEngine = null;
    }
    console.info('[VoiceService] Destroyed');
  }
}

// 单例导出
export const voiceService = new VoiceService();