import common from '@ohos.app.ability.common';
import Want from '@ohos.app.ability.Want';
import SoundEffectPlayer from '../utils/SoundEffectPlayer';

interface ReminderCard {
  id: string;
  timeLabel: string;
  medicine: string;
  dosage: string;
  mealHint: string;
  critical: boolean;
  taken: boolean;
}

interface TargetApp {
  id: string;
  label: string;
  bundleName: string;
  moduleName: string;
  abilityName: string;
  serviceName: string;
}

const COMMAND_OPEN_ENTRY: string = 'open-entry';
const START_WITHOUT_TIPS_FLAG: number = 0x100000;
const LAUNCH_SOUND_FILE: string = 'launch.wav';
const RETURN_SOUND_FILE: string = 'return.wav';

@Entry
@Component
struct Index {
  private readonly centerApp: TargetApp = {
    id: 'app-center',
    label: '应用中心',
    bundleName: 'com.zerows.appcenter',
    moduleName: 'entry',
    abilityName: 'EntryAbility',
    serviceName: 'AppBridgeService'
  };
  private readonly monitorApp: TargetApp = {
    id: 'app-monitor',
    label: '监控中心',
    bundleName: 'com.zerows.appmonitor',
    moduleName: 'entry',
    abilityName: 'EntryAbility',
    serviceName: 'AppBridgeService'
  };
  @State private followUpText: string = '今日首剂将在 08:00 提醒，默认开启大字与高对比度展示。';
  @State private reminders: ReminderCard[] = [
    {
      id: 'morning',
      timeLabel: '08:00',
      medicine: '降压药',
      dosage: '1 片',
      mealHint: '早餐后 30 分钟',
      critical: true,
      taken: false
    },
    {
      id: 'noon',
      timeLabel: '12:30',
      medicine: '胃药',
      dosage: '1 袋',
      mealHint: '午餐前 15 分钟',
      critical: false,
      taken: false
    },
    {
      id: 'evening',
      timeLabel: '19:00',
      medicine: '钙片',
      dosage: '2 片',
      mealHint: '晚餐后服用',
      critical: false,
      taken: true
    }
  ];
  private readonly carePoints: string[] = [
    '大字体卡片，减少阅读负担',
    '漏服后优先提醒家属或照护者',
    '和应用中心、监控中心保持联动'
  ];
  private readonly soundEffectPlayer: SoundEffectPlayer = new SoundEffectPlayer();

  private getAbilityContext(): common.UIAbilityContext {
    const hostContext = this.getUIContext().getHostContext();
    if (!hostContext) {
      throw new Error('UIAbilityContext is unavailable');
    }
    return hostContext as common.UIAbilityContext;
  }

  private buildEntryWant(target: TargetApp, scene: string): Want {
    return {
      bundleName: target.bundleName,
      moduleName: target.moduleName,
      abilityName: target.abilityName,
      flags: START_WITHOUT_TIPS_FLAG,
      parameters: {
        command: COMMAND_OPEN_ENTRY,
        starterApp: 'app-medication',
        coordinationScene: scene,
        sourceLabel: '用药提醒',
        startedAt: Date.now()
      }
    };
  }

  private async launchApp(target: TargetApp, scene: string): Promise<void> {
    try {
      await this.getAbilityContext().startAbility(this.buildEntryWant(target, scene));
      this.followUpText = '已打开 ' + target.label + '，可以继续查看协同状态。';
    } catch (err) {
      this.followUpText = '拉起 ' + target.label + ' 失败，请检查安装状态。';
      console.error('Launch failed: ' + JSON.stringify(err));
    }
  }

  private async playAndLaunch(target: TargetApp, scene: string, soundFile: string): Promise<void> {
    await this.soundEffectPlayer.play(this.getAbilityContext(), soundFile);
    await this.launchApp(target, scene);
  }

  private getTakenCount(): number {
    let count = 0;
    this.reminders.forEach((item: ReminderCard) => {
      if (item.taken) {
        count += 1;
      }
    });
    return count;
  }

  private markTaken(reminderId: string): void {
    this.reminders = this.reminders.map((item: ReminderCard) => {
      if (item.id === reminderId) {
        return {
          id: item.id,
          timeLabel: item.timeLabel,
          medicine: item.medicine,
          dosage: item.dosage,
          mealHint: item.mealHint,
          critical: item.critical,
          taken: true
        };
      }
      return item;
    });
    this.followUpText = '已登记服药。若连续漏服，可在后续版本升级为家属通知。';
  }

  private snoozeReminder(reminderId: string): void {
    const target = this.reminders.find((item: ReminderCard) => item.id === reminderId);
    this.followUpText = (target?.medicine ?? '当前提醒') + ' 已延后 10 分钟，请留意下一次振铃。';
  }

  private notifyFamily(): void {
    this.followUpText = '已记录家属协助需求。MVP 阶段先展示状态，后续可接入电话或短信能力。';
  }

  @Builder
  private buildReminderCard(item: ReminderCard) {
    Column({ space: 12 }) {
      Row() {
        Column({ space: 4 }) {
          Text(item.timeLabel)
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor('#102A43')
          Text(item.mealHint)
            .fontSize(14)
            .fontColor('#5B6C7D')
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        Text(item.taken ? '已完成' : (item.critical ? '关键提醒' : '待提醒'))
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(item.taken ? '#0B7A5A' : '#B45309')
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .borderRadius(999)
          .backgroundColor(item.taken ? '#DCFCE7' : '#FEF3C7')
      }
      .width('100%')

      Text(item.medicine)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor('#0F172A')
      Text(item.dosage)
        .fontSize(18)
        .fontColor('#475569')

      Row({ space: 10 }) {
        Button(item.taken ? '已服药' : '确认服药')
          .layoutWeight(1)
          .fontSize(18)
          .backgroundColor(item.taken ? '#CFEBDC' : '#0F766E')
          .onClick(() => {
            if (item.taken) {
              return;
            }
            this.markTaken(item.id);
          })
        Button('延后 10 分钟')
          .layoutWeight(1)
          .fontSize(18)
          .backgroundColor('#FFF7ED')
          .fontColor('#9A3412')
          .onClick(() => {
            this.snoozeReminder(item.id);
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding(18)
    .borderRadius(24)
    .backgroundColor('#FFFFFF')
    .border({
      width: 1,
      color: item.critical ? '#F59E0B' : '#E2E8F0'
    })
  }

  build() {
    Scroll() {
      Column({ space: 18 }) {
        Column({ space: 10 }) {
          Text('长辈用药提醒')
            .fontSize(36)
            .fontWeight(FontWeight.Bold)
            .fontColor('#102A43')
          Text('围绕高血压、慢病和日常保健场景，优先保证提醒准时、信息清楚、操作简单。')
            .fontSize(17)
            .fontColor('#486581')
          Text('从应用中心进入时系统可能确认一次；返回应用中心保持低摩擦。')
            .fontSize(13)
            .fontColor('#7B8794')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        Row({ space: 14 }) {
          Column({ space: 6 }) {
            Text('' + this.getTakenCount())
              .fontSize(30)
              .fontWeight(FontWeight.Bold)
              .fontColor('#0F172A')
            Text('已完成')
              .fontSize(14)
              .fontColor('#5B6C7D')
          }
          .layoutWeight(1)
          .padding(18)
          .borderRadius(22)
          .backgroundColor('#FFFFFF')

          Column({ space: 6 }) {
            Text('' + (this.reminders.length - this.getTakenCount()))
              .fontSize(30)
              .fontWeight(FontWeight.Bold)
              .fontColor('#0F172A')
            Text('待处理')
              .fontSize(14)
              .fontColor('#5B6C7D')
          }
          .layoutWeight(1)
          .padding(18)
          .borderRadius(22)
          .backgroundColor('#FFF7ED')
        }
        .width('100%')

        Text(this.followUpText)
          .width('100%')
          .padding(16)
          .borderRadius(20)
          .fontSize(17)
          .fontColor('#92400E')
          .backgroundColor('#FEF3C7')

        ForEach(this.carePoints, (item: string) => {
          Text(item)
            .width('100%')
            .padding(16)
            .borderRadius(18)
            .fontSize(17)
            .fontColor('#102A43')
            .backgroundColor('#FFFFFF')
        })

        ForEach(this.reminders, (item: ReminderCard) => {
          this.buildReminderCard(item);
        })

        Button('通知家属协助')
          .width('100%')
          .fontSize(20)
          .backgroundColor('#BE123C')
          .onClick(() => {
            this.notifyFamily();
          })
        Button('打开监控中心')
          .width('100%')
          .fontSize(20)
          .backgroundColor('#0F766E')
          .onClick(() => {
            void this.playAndLaunch(this.monitorApp, 'medication-open-monitor', LAUNCH_SOUND_FILE);
          })
        Button('返回应用中心')
          .width('100%')
          .fontSize(20)
          .backgroundColor('#1D4ED8')
          .onClick(() => {
            void this.playAndLaunch(this.centerApp, 'medication-back-to-center', RETURN_SOUND_FILE);
          })
      }
      .width('100%')
      .padding(22)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFF8F1')
  }
}
