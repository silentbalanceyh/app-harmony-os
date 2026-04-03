/**
 * 语音交互服务
 * 使用 @hms.ai.speechRecognizer 和 @hms.ai.textToSpeech
 */

import common from '@ohos.app.ability.common';
import speechRecognizer from '@hms.ai.speechRecognizer';
import textToSpeech from '@hms.ai.textToSpeech';
import audio from '@ohos.multimedia.audio';
import abilityAccessCtrl, { Permissions } from '@ohos.abilityAccessCtrl';
import { ReminderStore } from './ReminderStore';
import { formatTimeSlot } from '../models/ReminderModel';

const WAKEUP_WORD = '小药小药';

export interface VoiceResult {
  success: boolean;
  text?: string;
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

  private isListening: boolean = false;
  private sessionId: string = '';

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
  }

  /**
   * 语音播报
   */
  async speak(text: string): Promise<void> {
    if (!this.ttsEngine) {
      console.error('[VoiceService] TTS engine not initialized');
      return;
    }

    return new Promise((resolve) => {
      this.ttsEngine!.setListener({
        onStart: (requestId: string, response: textToSpeech.StartResponse) => {
          console.info('[VoiceService] TTS started: ' + requestId);
        },
        onComplete: (requestId: string, response: textToSpeech.CompleteResponse) => {
          console.info('[VoiceService] TTS completed');
          resolve();
        },
        onStop: (requestId: string, response: textToSpeech.StopResponse) => {
          console.info('[VoiceService] TTS stopped');
        },
        onError: (requestId: string, errorCode: number, errorMessage: string) => {
          console.error('[VoiceService] TTS error: ' + errorMessage);
          resolve();
        }
      });

      this.ttsEngine!.speak(text, {
        requestId: Date.now().toString(),
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
   */
  async startRecognition(timeout: number = 30000): Promise<VoiceResult> {
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

    this.isListening = true;
    this.sessionId = Date.now().toString();

    return new Promise(async (resolve) => {
      const recognizedText: string[] = [];
      let audioCapturer: audio.AudioCapturer | null = null;

      this.asrEngine!.setListener({
        onStart: (sessionId: string, eventMessage: string) => {
          console.info('[VoiceService] Recognition started');
        },
        onEvent: (sessionId: string, eventCode: number, eventMessage: string) => {
          console.info('[VoiceService] Event: ' + eventCode);
        },
        onResult: (sessionId: string, result: speechRecognizer.SpeechRecognitionResult) => {
          if (result.result) {
            recognizedText.push(result.result);
            console.info('[VoiceService] Partial result: ' + result.result);
          }
        },
        onComplete: (sessionId: string, eventMessage: string) => {
          this.isListening = false;
          // 停止音频采集
          if (audioCapturer) {
            audioCapturer.stop().then(() => audioCapturer?.release()).catch(() => {});
          }
          const fullText = recognizedText.join('');
          console.info('[VoiceService] Recognition complete: ' + fullText);

          if (fullText) {
            const parsed = this.parseVoiceCommand(fullText);
            resolve(parsed);
          } else {
            resolve({ success: false, error: '没有识别到语音，请再说一遍' });
          }
        },
        onError: (sessionId: string, errorCode: number, errorMessage: string) => {
          this.isListening = false;
          if (audioCapturer) {
            audioCapturer.stop().then(() => audioCapturer?.release()).catch(() => {});
          }
          console.error('[VoiceService] Recognition error: ' + errorMessage);
          resolve({ success: false, error: '识别失败：' + errorMessage });
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
            timeout: timeout
          }
        });
        console.info('[VoiceService] ASR startListening called');

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

        audioCapturer = await audio.createAudioCapturer(audioCapturerOptions);
        console.info('[VoiceService] AudioCapturer created');

        // 监听音频数据
        audioCapturer.on('readData', (buffer: ArrayBuffer) => {
          if (this.isListening && this.asrEngine) {
            // 将采集的音频写入 ASR 引擎
            const uint8Array = new Uint8Array(buffer);
            this.asrEngine.writeAudio(this.sessionId, uint8Array);
          }
        });

        // 开始采集
        await audioCapturer.start();
        console.info('[VoiceService] AudioCapturer started');

      } catch (e) {
        this.isListening = false;
        console.error('[VoiceService] Start recognition failed: ' + JSON.stringify(e));
        resolve({ success: false, error: '启动识别失败: ' + JSON.stringify(e) });
      }
    });
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
   * 解析语音命令
   */
  parseVoiceCommand(text: string): VoiceResult {
    const lowerText = text.toLowerCase();

    // 查询命令
    if (lowerText.includes('下次') || lowerText.includes('什么时候') || lowerText.includes('查询')) {
      return {
        success: true,
        text: '查询下次提醒'
      };
    }

    // 设置提醒命令
    const timeMatch = this.extractTime(text);
    const medicineMatch = this.extractMedicine(text);
    const dosageMatch = this.extractDosage(text);
    const frequencyMatch = this.extractFrequency(text);

    if (timeMatch && medicineMatch) {
      return {
        success: true,
        text: text,
        time: timeMatch,
        medicineName: medicineMatch,
        dosage: dosageMatch || '1片',
        frequency: frequencyMatch || '每天'
      };
    }

    return {
      success: false,
      text: text,
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
   * 提取药名
   */
  private extractMedicine(text: string): string | null {
    const medicineKeywords = [
      '降压药', '降糖药', '胃药', '钙片', '维生素',
      '止痛药', '感冒药', '消炎药', '心脏药', '胰岛素',
      '阿司匹林', '布洛芬', '感冒灵', '板蓝根', '头孢'
    ];

    for (const keyword of medicineKeywords) {
      if (text.includes(keyword)) {
        return keyword;
      }
    }

    const eatMatch = text.match(/吃(.+?)(一片|两片|一袋|两袋|半片)?/);
    if (eatMatch) {
      return eatMatch[1].trim();
    }

    return null;
  }

  /**
   * 提取剂量
   */
  private extractDosage(text: string): string | null {
    const patterns = [
      /一片/,
      /两片/,
      /三片/,
      /一袋/,
      /两袋/,
      /半片/,
      /(\d+)片/,
      /(\d+)袋/
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