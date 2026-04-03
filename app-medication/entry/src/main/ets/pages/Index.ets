/**
 * 用药提醒主页面 - Design.md 新修订版实现
 * 页面布局：拍照按钮（顶）→ 今日提醒+卡片 → 公共按钮（底）
 * 核心原则：大字、高对比、少元素、无冗余
 */

import common from '@ohos.app.ability.common';
import Want from '@ohos.app.ability.Want';
import vibrator from '@ohos.vibrator';
import abilityAccessCtrl, { Permissions } from '@ohos.abilityAccessCtrl';
import picker from '@ohos.file.picker';
import { cameraPicker, camera } from '@kit.CameraKit';
import { BusinessError } from '@ohos.base';
import { MedicineReminder, ReminderStatus } from '../models/ReminderModel';
import { reminderStore } from '../services/ReminderStore';
import { voiceService, VoiceResult } from '../services/VoiceService';
import { cameraOcrService, OcrResult } from '../services/CameraOcrService';
import { strongReminderService, ReminderTrigger } from '../services/StrongReminderService';
import SoundEffectPlayer from '../utils/SoundEffectPlayer';

interface TargetApp {
  id: string;
  label: string;
  bundleName: string;
  moduleName: string;
  abilityName: string;
}

const COMMAND_OPEN: string = 'open-entry';
const START_FLAG: number = 0x100000;
const SOUND_LAUNCH: string = 'launch.wav';
const SOUND_RETURN: string = 'return.wav';

// 设计规范配色
interface DesignColors {
  background: string;
  cameraButton: string;
  cameraButtonPress: string;
  cardBg: string;
  textBlack: string;
  textGray: string;
  textHint: string;
  statusGreen: string;
  statusGray: string;
  btnCenter: string;
  btnMonitor: string;
}

const COLORS: DesignColors = {
  background: '#F5F5F5',
  cameraButton: '#FF6B6B',
  cameraButtonPress: '#E55353',
  cardBg: '#FFFFFF',
  textBlack: '#333333',
  textGray: '#757575',
  textHint: '#9E9E9E',
  statusGreen: '#34A853',
  statusGray: '#9E9E9E',
  btnCenter: '#1D4ED8',
  btnMonitor: '#0F766E'
};

@Entry
@Component
struct Index {
  private readonly centerApp: TargetApp = {
    id: 'app-center', label: '应用中心',
    bundleName: 'com.zerows.appcenter', moduleName: 'entry', abilityName: 'EntryAbility'
  };
  private readonly monitorApp: TargetApp = {
    id: 'app-monitor', label: '监控中心',
    bundleName: 'com.zerows.appmonitor', moduleName: 'entry', abilityName: 'EntryAbility'
  };

  @State private reminders: MedicineReminder[] = [];
  @State private isCapturing: boolean = false;
  @State private isListening: boolean = false;  // 语音识别中
  @State private showDelete: boolean = false;
  @State private deleteId: string = '';
  @State private medName: string = '';
  @State private medImage: string = '';
  @State private medFrequency: string = '';  // 一天几次
  @State private medDosage: string = '';     // 一次多少
  @State private voicePrompt: string = '';   // 语音提示文字（视觉反馈）
  @State private showVoicePrompt: boolean = false;  // 显示语音提示

  private sound: SoundEffectPlayer = new SoundEffectPlayer();
  private store = reminderStore;
  private voice = voiceService;
  private camera = cameraOcrService;
  private reminder = strongReminderService;

  /**
   * 请求相机和麦克风权限（应用启动时调用）
   */
  private async requestPermissions(): Promise<void> {
    try {
      const atManager = abilityAccessCtrl.createAtManager();
      const context = this.getContext();

      // 并行请求相机和麦克风权限
      const permissions: Permissions[] = [
        'ohos.permission.CAMERA',
        'ohos.permission.MICROPHONE'
      ];

      console.info('[Index] Requesting permissions: ' + JSON.stringify(permissions));
      const result = await atManager.requestPermissionsFromUser(context, permissions);
      console.info('[Index] Permission result: ' + JSON.stringify(result));

      if (result.authResults) {
        for (let i = 0; i < result.authResults.length; i++) {
          const status = result.authResults[i] === 0 ? 'GRANTED' : 'DENIED';
          console.info('[Index] ' + permissions[i] + ' = ' + status);
        }
      }
    } catch (e) {
      console.error('[Index] Request permissions failed: ' + JSON.stringify(e));
    }
  }

  aboutToAppear(): void {
    const ctx = this.getContext();
    void this.initAll(ctx);
    void this.loadList();
    // 启动时主动请求权限
    void this.requestPermissions();
  }

  aboutToDisappear(): void {
    void this.voice.destroy();
    void this.camera.destroy();
    void this.reminder.destroy();
  }

  private async initAll(ctx: common.UIAbilityContext): Promise<void> {
    try {
      await this.store.init(ctx);
      await this.voice.init(ctx, this.store);
      await this.camera.init(ctx);
      await this.reminder.init(ctx, this.store);
      console.info('[Index] Init OK');
    } catch (e) {
      console.error('[Index] Init err: ' + JSON.stringify(e));
    }
  }

  private async loadList(): Promise<void> {
    try {
      this.reminders = await this.store.getTodayReminders();
      // 按状态和时间排序：未提醒在上，漏服在中，已服药在下
      this.reminders = this.sortReminders(this.reminders);
    } catch (e) {
      console.error('[Index] Load err');
    }
  }

  /**
   * 提醒排序逻辑：
   * 1. 未提醒（当前时间 < 提醒时间）→ 最上面，绿色
   * 2. 已提醒（当前时间 > 提醒时间 或 已响应）→ 下面，灰色
   */
  private sortReminders(list: MedicineReminder[]): MedicineReminder[] {
    const now = new Date();
    const currentMinutes = now.getHours() * 60 + now.getMinutes();

    return list.sort((a: MedicineReminder, b: MedicineReminder) => {
      const aMinutes = this.parseTimeToMinutes(a.time);
      const bMinutes = this.parseTimeToMinutes(b.time);

      // 获取实际状态（考虑时间过期）
      const aStatus = this.getActualStatus(a, currentMinutes, aMinutes);
      const bStatus = this.getActualStatus(b, currentMinutes, bMinutes);

      // 排序优先级：未提醒 > 已提醒
      const priorityMap = new Map<string, number>();
      priorityMap.set('pending', 0);    // 未提醒 - 最高优先级
      priorityMap.set('reminded', 1);   // 已提醒 - 低优先级

      const aPriority = priorityMap.get(aStatus) ?? 2;
      const bPriority = priorityMap.get(bStatus) ?? 2;

      // 同状态按时间排序
      if (aPriority !== bPriority) {
        return aPriority - bPriority;
      }
      return aMinutes - bMinutes;
    });
  }

  /**
   * 解析时间字符串为分钟数
   */
  private parseTimeToMinutes(timeStr: string): number {
    const parts = timeStr.split(':');
    const hour = parseInt(parts[0], 10);
    const minute = parseInt(parts[1], 10);
    return hour * 60 + minute;
  }

  /**
   * 获取实际状态（提醒视角，非监督视角）
   * 时间未到 → 未提醒
   * 时间已过/已响应 → 已提醒
   */
  private getActualStatus(r: MedicineReminder, currentMinutes: number, reminderMinutes: number): string {
    // 已响应提醒（点击确认/停止）→ 已提醒
    if (r.status === ReminderStatus.TAKEN || r.status === ReminderStatus.REMINDED) {
      return 'reminded';
    }

    // 时间已过 → 提醒已发送 → 已提醒
    if (currentMinutes > reminderMinutes) {
      return 'reminded';
    }

    // 时间未到 → 未提醒
    return 'pending';
  }

  /**
   * 获取状态显示文本
   */
  private getStatusText(r: MedicineReminder): string {
    const now = new Date();
    const currentMinutes = now.getHours() * 60 + now.getMinutes();
    const reminderMinutes = this.parseTimeToMinutes(r.time);
    const actualStatus = this.getActualStatus(r, currentMinutes, reminderMinutes);

    switch (actualStatus) {
      case 'pending':
        return '未提醒';
      case 'reminded':
        return '已提醒';
      default:
        return '未提醒';
    }
  }

  /**
   * 获取状态颜色
   */
  private getStatusColor(r: MedicineReminder): string {
    const now = new Date();
    const currentMinutes = now.getHours() * 60 + now.getMinutes();
    const reminderMinutes = this.parseTimeToMinutes(r.time);
    const actualStatus = this.getActualStatus(r, currentMinutes, reminderMinutes);

    switch (actualStatus) {
      case 'pending':
        return COLORS.statusGreen;  // 绿色 - 未提醒（待提醒）
      case 'reminded':
        return COLORS.statusGray;   // 灰色 - 已提醒（提醒已发送）
      default:
        return COLORS.statusGreen;
    }
  }

  private getContext(): common.UIAbilityContext {
    const host = this.getUIContext().getHostContext();
    if (!host) throw new Error('No context');
    return host as common.UIAbilityContext;
  }

  private buildWant(app: TargetApp, scene: string): Want {
    return {
      bundleName: app.bundleName,
      moduleName: app.moduleName,
      abilityName: app.abilityName,
      flags: START_FLAG,
      parameters: { command: COMMAND_OPEN, starter: 'app-medication', scene, startedAt: Date.now() }
    };
  }

  private async goApp(app: TargetApp, scene: string): Promise<void> {
    try { await this.getContext().startAbility(this.buildWant(app, scene)); }
    catch (e) { console.error('Go err'); }
  }

  private async playGo(app: TargetApp, scene: string, snd: string): Promise<void> {
    await this.sound.play(this.getContext(), snd);
    await this.goApp(app, scene);
  }

  /**
   * 请求相机权限
   */
  private async requestCameraPermission(): Promise<boolean> {
    try {
      const atManager = abilityAccessCtrl.createAtManager();
      const context = this.getContext();
      const tokenID = context.applicationInfo.accessTokenId;

      // 先检查是否已有权限
      const grantStatus = await atManager.verifyAccessToken(tokenID, 'ohos.permission.CAMERA');
      if (grantStatus === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
        console.info('[Index] Camera permission already granted');
        return true;
      }

      // 请求权限
      console.info('[Index] Requesting camera permission...');
      const result = await atManager.requestPermissionsFromUser(context, ['ohos.permission.CAMERA']);
      console.info('[Index] Permission result: ' + JSON.stringify(result));

      if (result.authResults && result.authResults.length > 0 && result.authResults[0] === 0) {
        return true;
      }
      return false;
    } catch (e) {
      console.error('[Index] Request camera permission failed: ' + JSON.stringify(e));
      return false;
    }
  }

  /**
   * 拍照功能
   * 流程：请求权限 → 打开相机拍照 → 启动语音多轮对话
   */
  private async doCapture(): Promise<void> {
    console.info('[Index] doCapture called, isCapturing=' + this.isCapturing);
    if (this.isCapturing) {
      console.warn('[Index] Already capturing, skip');
      return;
    }
    this.isCapturing = true;
    this.vib(50);

    // 直接使用 photoPicker（在模拟器上 cameraPicker 不可用）
    // photoPicker 在真机会显示相机按钮，模拟器上可以选图片
    try {
      console.info('[Index] Opening photoPicker...');
      const photoPicker = new picker.PhotoViewPicker();
      const selectResult = await photoPicker.select({
        MIMEType: picker.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 1
      });

      console.info('[Index] photoPicker result: ' + JSON.stringify(selectResult));

      if (selectResult.photoUris && selectResult.photoUris.length > 0) {
        this.medImage = selectResult.photoUris[0];
        console.info('[Index] Image selected: ' + this.medImage);
        this.isCapturing = false;
        await this.startVoiceDialogFlow();
        return;
      } else {
        console.warn('[Index] photoPicker returned no photoUris');
      }
    } catch (e) {
      console.error('[Index] photoPicker failed: ' + JSON.stringify(e));
    }

    this.isCapturing = false;
    console.info('[Index] doCapture finished with no image');
  }

  /**
   * 显示语音提示（视觉反馈）
   */
  /**
   * 显示语音提示文本（不自动隐藏，需要手动调用 hidePrompt）
   */
  private showPrompt(text: string): void {
    this.voicePrompt = text;
    this.showVoicePrompt = true;
  }

  /**
   * 隐藏语音提示文本
   */
  private hidePrompt(): void {
    this.showVoicePrompt = false;
  }

  /**
   * 等待指定毫秒（让老人看清提示文本）
   */
  private waitMs(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  /**
   * 同步语音交互步骤：显示文本 → TTS播报 → 语音识别 → 返回结果
   * @param promptText 提示文本
   * @param defaultResult 默认结果
   * @param parseMedicine 是否进行药品解析（Step 1问药品名时为true，其他步骤为false）
   */
  private async voiceStep(promptText: string, defaultResult: string, parseMedicine: boolean = true): Promise<string> {
    // 1. 显示提示文本
    this.showPrompt(promptText);

    // 2. TTS 播报（文本持续显示）
    await this.voice.speak(promptText);

    // 3. 语音识别（文本持续显示，让老人看清问题）
    const result = await this.voice.startRecognition(30000, parseMedicine);

    // 4. 返回识别结果
    if (result.text) {
      return result.text;
    }
    return defaultResult;
  }

  /**
   * 语音多轮对话流程
   * Step 1: 问药品名称
   * Step 2: 问一天吃几次
   * Step 3: 问一次吃多少
   * Step 4: 确认并创建提醒
   */
  private async startVoiceDialogFlow(): Promise<void> {
    if (this.isListening) return;
    this.isListening = true;

    try {
      // Step 1: 问药品名称（需要药品解析）
      this.showPrompt('请说药品名称');
      await this.voice.speak('请说药品名称');
      const result1 = await this.voice.startRecognition(30000, true);  // parseMedicine=true
      this.medName = result1.medicineName || result1.text || '药品';

      // Step 1 确认：显示文本 → 等待TTS播报完成 → 停留让老人看清
      this.showPrompt('好的，' + this.medName);
      await this.voice.speak('好的，' + this.medName);
      await this.waitMs(1000);

      // Step 2: 问一天吃几次（不需要药品解析）
      let resultText = await this.voiceStep('一天吃几次？', '一天一次', false);  // parseMedicine=false
      console.info('[Index] Step2 ASR result: ' + resultText);
      this.medFrequency = this.parseFrequencyFromText(resultText);
      console.info('[Index] Step2 parsed frequency: ' + this.medFrequency);

      // Step 2 确认
      this.showPrompt('好的，' + this.medFrequency);
      await this.voice.speak('好的，' + this.medFrequency);
      await this.waitMs(1000);

      // Step 3: 问一次吃多少（不需要药品解析）
      resultText = await this.voiceStep('一次吃多少？', '1片', false);  // parseMedicine=false
      this.medDosage = this.parseDosageFromText(resultText);

      // Step 3 确认
      this.showPrompt('好的，一次' + this.medDosage);
      await this.voice.speak('好的，一次' + this.medDosage);
      await this.waitMs(1000);

      // Step 4: 最终确认并创建提醒
      const times = this.resolveTimesFromFrequency(this.medFrequency);
      const confirmMsg = '已设置 ' + this.medName + '，' + this.medFrequency +
                         (times.length > 1 ? '' : '，' + times[0] + '提醒') +
                         '，每次' + this.medDosage;

      // 最终确认：显示文本 → 等待TTS完成 → 创建提醒 → 额外停留
      this.showPrompt(confirmMsg);
      await this.voice.speak('好的，' + confirmMsg);  // 同步等待 TTS 完成

      // 创建提醒（文本持续显示）
      for (let i = 0; i < times.length; i++) {
        const t = times[i];
        try {
          const r = await this.store.addReminder(t, this.medName, this.medDosage, this.medImage);
          await this.reminder.registerReminder(r);
        } catch (e) {
          console.error('[Index] Add reminder failed: ' + JSON.stringify(e));
        }
      }

      // 刷新列表
      await this.loadList();

      // 播报完成后额外等待1秒
      await this.waitMs(1000);
      this.hidePrompt();

      // 清空临时数据
      this.medName = '';
      this.medImage = '';
      this.medFrequency = '';
      this.medDosage = '';

    } catch (e) {
      console.error('[Index] Voice dialog failed: ' + JSON.stringify(e));
      await this.voice.speak('设置失败，请重试');
    }

    this.isListening = false;
  }

  /**
   * 从语音文本解析频率
   */
  private parseFrequencyFromText(text: string): string {
    console.info('[Index] parseFrequencyFromText input: ' + text);

    // ASR常见误识别优先处理
    // "三例" - 用户说"两次"时ASR常见误识别
    if (text.includes('三例') || text.includes('三类')) {
      console.info('[Index] Matched: 两次 (ASR误识别: 三例/三类)');
      return '一天两次';
    }

    // 三次：支持多种表达和ASR误识别
    // 正常: "三次"、"3次"、"三回"
    // 简短: "三"、"3"
    // ASR误识别: "安次"、"散次"（"三"的同音字误识别）
    if (text.includes('三次') || text.includes('3次') || text.includes('三回') ||
        text.includes('安次') || text.includes('散次') || text.includes('伞次') ||
        text === '三' || text === '3' || text === '三个' || text === '三遍' ||
        /安.*次/.test(text) || /散.*次/.test(text) || /伞.*次/.test(text)) {
      console.info('[Index] Matched: 三次');
      return '一天三次';
    }

    // 两次：支持多种表达和ASR误识别
    // 正常: "两次"、"2次"、"两回"
    // 简短: "两"、"2"、"二"
    // ASR误识别: "两类"、"两力"、"俩次"
    if (text.includes('两次') || text.includes('2次') || text.includes('两回') ||
        text.includes('二次') || text.includes('二回') ||
        text.includes('两类') || text.includes('两力') || text.includes('两立') ||
        text.includes('俩次') || text.includes('俩例') ||
        text === '两' || text === '2' || text === '二' ||
        text === '俩' || text === '两个' || text === '两遍' ||
        /2.*次/.test(text) || /两.*次/.test(text) || /二.*次/.test(text)) {
      console.info('[Index] Matched: 两次');
      return '一天两次';
    }

    // 一次：支持多种表达
    // 正常: "一次"、"1次"、"一回"
    // 简短: "一"、"1"
    // ASR误识别: "依次"、"医次"
    if (text.includes('一次') || text.includes('1次') || text.includes('一回') ||
        text.includes('依次') || text.includes('医次') ||
        text === '一' || text === '1' || text === '一个' || text === '一遍') {
      console.info('[Index] Matched: 一次');
      return '一天一次';
    }

    // 默认
    console.info('[Index] No match, using default: 一天一次');
    return '一天一次';
  }

  /**
   * 从语音文本解析剂量（统一输出阿拉伯数字）
   */
  private parseDosageFromText(text: string): string {
    console.info('[Index] parseDosageFromText input: ' + text);

    // 中文数字到阿拉伯数字的映射
    const chineseToNumber: Record<string, string> = {
      '半': '0.5', '一': '1', '二': '2', '两': '2', '三': '3', '四': '4', '五': '5',
      '六': '6', '七': '7', '八': '8', '九': '9', '十': '10'
    };

    // 支持的单位
    const units = ['片', '颗', '粒', '袋', '包', '勺', '支', '丸', '滴', '个', '瓶'];

    // 0. ASR常见误识别优先处理
    // "例" → 可能是"两粒"的误识别
    // "力" → 可能是"两粒"的误识别
    if (text === '例' || text === '两例' || text === '三例') {
      console.info('[Index] Matched: 2粒 (ASR误识别)');
      return '2粒';
    }
    if (text.includes('力') && !text.includes('粒')) {
      console.info('[Index] Matched: 2粒 (ASR误识别: 力)');
      return '2粒';
    }

    // 1. 匹配 "数字+单位" 格式（已经是阿拉伯数字）
    const digitMatch = text.match(/(\d+(?:\.\d+)?)\s*(片|颗|粒|袋|包|勺|支|丸|滴|个|瓶)/);
    if (digitMatch) {
      return digitMatch[1] + digitMatch[2];
    }

    // 2. 匹配 "中文数字+单位" 格式
    const chineseNums = ['半', '一', '二', '两', '三', '四', '五', '六', '七', '八', '九', '十'];
    for (const unit of units) {
      for (const cn of chineseNums) {
        if (text.includes(cn + unit)) {
          return chineseToNumber[cn] + unit;
        }
      }
    }

    // 3. 匹配 "半" 开头的
    if (text.includes('半片')) return '0.5片';
    if (text.includes('半颗')) return '0.5颗';
    if (text.includes('半粒')) return '0.5粒';
    if (text.includes('半袋')) return '0.5袋';

    // 4. 用户只说数字没有单位（如"两个"、"三个"）
    for (const cn of chineseNums) {
      if (text === cn || text === cn + '个') {
        console.info('[Index] Matched: ' + chineseToNumber[cn] + '片 (无单位默认)');
        return chineseToNumber[cn] + '片';
      }
    }

    return '1片';
  }

  /**
   * 根据频率解析出具体时间点
   */
  private resolveTimesFromFrequency(frequency: string): string[] {
    switch (frequency) {
      case '一天三次':
        return ['08:00', '12:00', '18:00'];
      case '一天两次':
        return ['08:00', '17:00'];
      case '一天一次':
      default:
        return ['08:00'];
    }
  }

  /**
   * 长按拍照按钮触发语音识别（多轮对话流程）
   */
  private async startVoiceInput(): Promise<void> {
    if (this.isListening) return;
    this.vib(100);  // 震动提示开始录音

    // 长按没有图片，清空 medImage
    this.medImage = '';

    // 使用和点击拍照相同的多轮对话流程
    // 注意：isListening 由 startVoiceDialogFlow 内部管理
    await this.startVoiceDialogFlow();
  }

  /**
   * 取消语音识别
   */
  private async cancelVoiceInput(): Promise<void> {
    if (!this.isListening) return;

    this.isListening = false;
    await this.voice.stopRecognition();
    await this.voice.speak('已取消');
    this.vib(50);
  }

  /**
   * 处理语音识别结果，自动创建提醒
   */
  private async processVoiceResult(result: VoiceResult): Promise<void> {
    const medicineName = result.medicineName || '药品';
    const time = result.time;
    const dosage = result.dosage || '1片';
    const frequency = result.frequency;

    // 根据频率确定时间点
    const times: string[] = this.resolveTimes(time, frequency);

    // 为每个时间点创建提醒
    for (let i = 0; i < times.length; i++) {
      const t = times[i];
      try {
        const r = await this.store.addReminder(t, medicineName, dosage, '');
        await this.reminder.registerReminder(r);
      } catch (e) {
        console.error('[Index] Add reminder failed: ' + JSON.stringify(e));
      }
    }

    // 语音播报确认
    let msg: string;
    if (times.length > 1) {
      msg = '已设置' + medicineName + '，每天' + times.length.toString() + '次，每次' + dosage;
    } else {
      msg = '已设置' + medicineName + '，' + times[0] + '提醒，每次' + dosage;
    }
    await this.voice.speak(msg);

    // 刷新列表
    await this.loadList();
  }

  /**
   * 根据用户说的时间和频率，解析出具体时间点
   */
  private resolveTimes(specificTime?: string, frequency?: string): string[] {
    // 用户指定了具体时间，直接用
    if (specificTime) {
      return [specificTime];
    }

    // 根据频率生成默认时间
    switch (frequency) {
      case '每天':
      case '一天一次':
        return ['08:00'];

      case '一天两次':
      case '每天两次':
      case '一日两次':
        return ['08:00', '17:00'];

      case '一天三次':
      case '每天三次':
      case '一日三次':
        return ['08:00', '12:00', '18:00'];

      case '隔天':
      case '隔日':
        return ['08:00'];

      default:
        // 默认一天一次
        return ['08:00'];
    }
  }

  private askDelete(id: string): void {
    this.deleteId = id;
    this.showDelete = true;
    this.vib(50);
  }

  private async doDelete(): Promise<void> {
    try {
      await this.reminder.cancelReminder(this.deleteId);
      await this.store.deleteReminder(this.deleteId);
      this.showDelete = false;
      this.deleteId = '';
      await this.loadList();
    } catch (e) { console.error('Del err'); }
  }

  private noDelete(): void {
    this.showDelete = false;
    this.deleteId = '';
  }

  /**
   * 根据药品名称字数动态调整字号
   * ≤4 字: 34px
   * 5-6 字: 28px
   * 7-8 字: 24px
   * >8 字: 20px
   */
  private getMedicineNameFontSize(name: string): number {
    const len = name.length;
    if (len <= 4) return 34;
    if (len <= 6) return 28;
    if (len <= 8) return 22;   // 7-8字：22px（进一步减小）
    if (len <= 10) return 18;  // 9-10字：18px
    return 16;                 // >10字：16px（最小字号）
  }

  private vib(ms: number): void {
    try { vibrator.vibrate(ms); } catch (e) {}
  }

  // ==================== 删除确认 ====================

  @Builder
  private deleteDialog() {
    Column({ space: 32 }) {
      Text('删除')
        .fontSize(48)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLORS.statusGreen)
        .padding(24)
        .onClick(() => { void this.doDelete(); this.vib(50); })
      Text('取消')
        .fontSize(48)
        .fontColor(COLORS.textBlack)
        .padding(24)
        .onClick(() => { this.noDelete(); this.vib(50); })
    }
    .width('100%')
    .padding(32)
    .backgroundColor(COLORS.cardBg)
    .borderRadius(24)
  }

  // ==================== 提醒卡片 ====================

  @Builder
  private card(r: MedicineReminder) {
    Column() {
      // 第一行：时间左上 + 状态右上
      Row() {
        Text(r.time)
          .fontSize(35)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLORS.textBlack)
        Blank()
        Text(this.getStatusText(r))
          .fontSize(32)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.getStatusColor(r))
      }.width('100%')

      Blank()

      // 第二行：图片左下 + 名称右下 + 剂量在名称下
      Row() {
        // 图片左下：80x80，无圆角
        if (r.medicineImage) {
          Image(r.medicineImage).width(80).height(80).objectFit(ImageFit.Cover)
        } else {
          Column() { Text('💊').fontSize(48) }
            .width(80).height(80).backgroundColor('#F0F0F0')
            .justifyContent(FlexAlign.Center)
        }

        Blank()

        // 名称右下 + 剂量在下，与图片间距10px
        Column({ space: 8 }) {
          Text(r.medicineName)
            .fontSize(this.getMedicineNameFontSize(r.medicineName))
            .fontColor(COLORS.textBlack)
          Text(r.dosage)
            .fontSize(25)
            .fontColor(COLORS.textGray)
        }.alignItems(HorizontalAlign.End).margin({ left: 10 })
      }.width('100%')

      // 底部提示
      Text('长按可删除此提醒')
        .fontSize(14)
        .fontColor(COLORS.textHint)
        .width('100%')
        .textAlign(TextAlign.Center)
        .margin({ top: 16 })
    }
    .width('100%')
    .height(180)
    .padding(24)
    .borderRadius(24)
    .backgroundColor(COLORS.cardBg)
    .justifyContent(FlexAlign.SpaceBetween)
    .gesture(
      LongPressGesture({ repeat: false, duration: 500 })
        .onAction(() => { this.askDelete(r.id); })
    )
  }

  // ==================== 主布局 ====================

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      // ========== 底层：可滚动内容区域 ==========
      Column() {
        // 今日提醒提示（顶部）
        Text('今日提醒')
          .fontSize(34)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLORS.textBlack)
          .width('100%')
          .padding({ left: 32, top: 24, bottom: 10 })

        // 卡片列表（可滑动区域）
        Scroll() {
          Column({ space: 24 }) {
            if (this.reminders.length > 0) {
              ForEach(this.reminders, (r: MedicineReminder) => { this.card(r); }, (r: MedicineReminder): string => r.id)
            } else {
              Column({ space: 12 }) {
                Text('📋')
                  .fontSize(48)
                Text('今日还没有提醒')
                  .fontSize(28)
                  .fontColor(COLORS.textHint)
                  .fontWeight(FontWeight.Normal)
              }
              .width('100%')
              .height(180)
              .justifyContent(FlexAlign.Center)
              .margin({ top: 20 })
            }
          }
          .width('100%')
          .padding({ left: 32, right: 32 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)

        // 拍照按钮（提醒卡片下方）
        Column() {
          Button() { Text('💊').fontSize(60) }
            .width(120)
            .height(120)
            .borderRadius(60)
            .backgroundColor(this.isListening ? '#4CAF50' : (this.isCapturing ? COLORS.cameraButtonPress : COLORS.cameraButton))
            .onClick(() => {
              console.info('[Index] Button onClick triggered');
              if (this.isListening) {
                void this.cancelVoiceInput();  // 正在语音识别时点击 = 取消
              } else {
                void this.doCapture();
              }
            })
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding({ top: 24, bottom: 120 })
        .gesture(
          LongPressGesture({ repeat: false, duration: 500 })
            .onAction(() => {
              console.info('[Index] LongPress triggered');
              void this.startVoiceInput();
            })
        ) // 为底部固定按钮预留空间
      }
      .width('100%')
      .height('100%')
      .backgroundColor(COLORS.background)

      // ========== 顶层：固定底部公共按钮 ==========
      Column() {
        Row({ space: 16 }) {
          Button('返回应用中心')
            .height(56)
            .fontSize(22)
            .backgroundColor(COLORS.btnCenter)
            .onClick(() => void this.playGo(this.centerApp, 'back', SOUND_RETURN))
          Button('打开监控中心')
            .height(56)
            .fontSize(22)
            .backgroundColor(COLORS.btnMonitor)
            .onClick(() => void this.playGo(this.monitorApp, 'open', SOUND_LAUNCH))
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .padding({ left: 32, right: 32, top: 24, bottom: 32 })
      }
      .width('100%')
      .backgroundColor(COLORS.background)

      // 弹层
      // 语音提示（视觉反馈）
      if (this.showVoicePrompt) {
        Column() {
          Blank()
          Column() {
            Text(this.voicePrompt)
              .fontSize(36)
              .fontColor(COLORS.textBlack)
              .textAlign(TextAlign.Center)
              .padding(32)
          }
          .backgroundColor(COLORS.cardBg)
          .borderRadius(24)
          .margin({ left: 32, right: 32 })
          Blank()
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#80000000')
      }
      if (this.showDelete) {
        Column() { Blank(); this.deleteDialog(); Blank(); }
          .width('100%').height('100%').backgroundColor('#80000000')
      }
    }
    .width('100%')
    .height('100%')
  }
}