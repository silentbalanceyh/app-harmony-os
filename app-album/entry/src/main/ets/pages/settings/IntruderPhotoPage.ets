import router from '@ohos.router';
import fs from '@ohos.file.fs';
import common from '@ohos.app.ability.common';
import { promptAction } from '@kit.ArkUI';
import { settingsStore } from '../../utils/SettingsStore';
import util from '@ohos.util';

interface IntruderRecord {
  photoPath: string;
  timestamp: number;
}

@Preview
@Entry
@Component
struct IntruderPhotoPage {
  @State intruderEnabled: boolean = false;
  @State records: IntruderRecord[] = [];

  aboutToAppear(): void {
    void this.loadSettings();
    this.loadRecords();
  }

  private getAbilityContext(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private async loadSettings(): Promise<void> {
    await settingsStore.init(this.getAbilityContext());
    this.intruderEnabled = await settingsStore.getIntruderPhotoEnabled();
  }

  private loadRecords(): void {
    try {
      const context = this.getAbilityContext();
      const recordsPath = context.filesDir + '/intruder_records.json';
      if (fs.accessSync(recordsPath)) {
        const file = fs.openSync(recordsPath, fs.OpenMode.READ_ONLY);
        const stat = fs.statSync(recordsPath);
        const buf = new ArrayBuffer(stat.size);
        fs.readSync(file.fd, buf);
        fs.closeSync(file);
        const decoder = util.TextDecoder.create('utf-8');
        const content = decoder.decodeToString(new Uint8Array(buf));
        this.records = JSON.parse(content) as IntruderRecord[];
      }
    } catch {
      this.records = [];
    }
  }

  private saveRecords(): void {
    try {
      const context = this.getAbilityContext();
      const recordsPath = context.filesDir + '/intruder_records.json';
      const file = fs.openSync(recordsPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
      const encoder = new util.TextEncoder();
      const data = encoder.encodeInto(JSON.stringify(this.records));
      fs.writeSync(file.fd, data.buffer);
      fs.closeSync(file);
    } catch (err) {
      console.error('Save intruder records failed:', JSON.stringify(err));
    }
  }

  private async toggleIntruder(isOn: boolean): Promise<void> {
    await settingsStore.setIntruderPhotoEnabled(isOn);
    this.intruderEnabled = isOn;
    promptAction.showToast({
      message: isOn ? '闯入者拍摄已开启' : '闯入者拍摄已关闭',
      duration: 2000
    });
  }

  private formatTime(timestamp: number): string {
    const date = new Date(timestamp);
    return `${date.getMonth() + 1}/${date.getDate()} ${date.getHours().toString().padStart(2, '0')}:${date.getMinutes().toString().padStart(2, '0')}`;
  }

  private handleDeleteRecord(index: number): void {
    this.records.splice(index, 1);
    this.saveRecords();
    promptAction.showToast({ message: '已删除记录', duration: 1500 });
  }

  private handleClearAll(): void {
    if (this.records.length === 0) return;
    AlertDialog.show({
      title: '清空记录',
      message: '确定要删除所有闯入者记录吗？',
      autoCancel: true,
      alignment: DialogAlignment.Center,
      gridCount: 4,
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: {
        value: '清空',
        fontColor: '#EF4444',
        action: () => {
          this.records = [];
          this.saveRecords();
          promptAction.showToast({ message: '已清空所有记录', duration: 1500 });
        }
      }
    });
  }

  build() {
    Column({ space: 12 }) {
      Row({ space: 12 }) {
        Button('←')
          .width(36).height(36).fontSize(18).fontColor('#111827')
          .backgroundColor('#FFFFFF').borderRadius(18)
          .onClick(() => { router.back(); })
        Text('闯入者拍摄')
          .fontSize(20).fontWeight(FontWeight.Bold).fontColor('#111827')
        Blank()
        if (this.records.length > 0) {
          Text('清空')
            .fontSize(14).fontColor('#EF4444')
            .onClick(() => { this.handleClearAll(); })
        }
      }
      .width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 })

      Row() {
        Text('启用闯入者拍摄')
          .fontSize(16).fontColor('#111827')
        Blank()
        Toggle({ type: ToggleType.Switch, isOn: this.intruderEnabled })
          .onChange((isOn: boolean) => { void this.toggleIntruder(isOn); })
      }
      .width('100%').padding(16).backgroundColor('#FFFFFF').borderRadius(8)
      .margin({ left: 16, right: 16 })

      if (this.records.length === 0) {
        Column() {
          Text('📸').fontSize(48)
          Text('暂无闯入记录').fontSize(16).fontColor('#6B7280').margin({ top: 12 })
          Text('开启后，输入错误密码时将自动拍摄').fontSize(13).fontColor('#9CA3AF').margin({ top: 4 })
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        List({ space: 8 }) {
          ForEach(this.records, (record: IntruderRecord, index: number) => {
            ListItem() {
              Row({ space: 12 }) {
                Column({ space: 4 }) {
                  Text(`闯入记录 #${index + 1}`)
                    .fontSize(14).fontColor('#111827').fontWeight(FontWeight.Medium)
                  Text(this.formatTime(record.timestamp))
                    .fontSize(12).fontColor('#9CA3AF')
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                Text('删除')
                  .fontSize(13).fontColor('#EF4444')
                  .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                  .onClick(() => { this.handleDeleteRecord(index as number); })
              }
              .width('100%').padding(16).backgroundColor('#FFFFFF').borderRadius(8)
            }
          }, (record: IntruderRecord, index: number) => index.toString())
        }
        .width('100%').layoutWeight(1).padding({ left: 16, right: 16 })
      }
    }
    .width('100%').height('100%').backgroundColor('#F3F6FC')
  }
}
