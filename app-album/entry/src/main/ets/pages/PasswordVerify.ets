import common from '@ohos.app.ability.common';
import { PasswordStore } from '../utils/PasswordStore';
import { settingsStore } from '../utils/SettingsStore';
import { cameraPicker } from '@kit.CameraKit';
import { userAuth } from '@kit.UserAuthenticationKit';
import router from '@ohos.router';
import { AlbumTheme } from '../utils/AlbumTheme';
import { fileRepo } from '../utils/FileRepoUtil';
import dataPreferences from '@ohos.data.preferences';
import fs from '@ohos.file.fs';
import util from '@ohos.util';

interface IntruderRecord {
  photoPath: string;
  timestamp: number;
}

@Preview
@Entry
@Component
struct PasswordVerify {
  @State inputDigits: string = '';
  @State errorMsg: string = '';
  @State faceIdAvailable: boolean = false;
  @State faceIdEnabled: boolean = false;
  private store: PasswordStore = new PasswordStore();
  private maxLen: number = 6;
  private intruderRecords: IntruderRecord[] = [];

  private getContext(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  async aboutToAppear(): Promise<void> {
    await this.store.init(this.getContext());
    await settingsStore.init(this.getContext());
    this.faceIdEnabled = await settingsStore.getFaceIdEnabled();
    if (this.faceIdEnabled) {
      this.faceIdAvailable = await this.checkFaceIdSupport();
      if (this.faceIdAvailable) {
        void this.tryFaceIdUnlock();
      }
    }
    this.loadIntruderRecords();
  }

  private loadIntruderRecords(): void {
    try {
      const context = this.getContext();
      const recordsPath = context.filesDir + '/intruder_records.json';
      if (fs.accessSync(recordsPath)) {
        const file = fs.openSync(recordsPath, fs.OpenMode.READ_ONLY);
        const stat = fs.statSync(recordsPath);
        const buf = new ArrayBuffer(stat.size);
        fs.readSync(file.fd, buf);
        fs.closeSync(file);
        const decoder = util.TextDecoder.create('utf-8');
        const content = decoder.decodeToString(new Uint8Array(buf));
        this.intruderRecords = JSON.parse(content) as IntruderRecord[];
      }
    } catch {
      this.intruderRecords = [];
    }
  }

  private saveIntruderRecords(): void {
    try {
      const context = this.getContext();
      const recordsPath = context.filesDir + '/intruder_records.json';
      const file = fs.openSync(recordsPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
      const encoder = new util.TextEncoder();
      const data = encoder.encodeInto(JSON.stringify(this.intruderRecords));
      fs.writeSync(file.fd, data.buffer);
      fs.closeSync(file);
    } catch (err) {
      console.error('Save intruder records failed:', JSON.stringify(err));
    }
  }

  private async checkFaceIdSupport(): Promise<boolean> {
    try {
      userAuth.getUserAuthInstance({
        challenge: new Uint8Array([0]),
        authType: [userAuth.UserAuthType.FACE],
        authTrustLevel: userAuth.AuthTrustLevel.ATL3
      }, { title: 'Face ID' });
      return true;
    } catch {
      return false;
    }
  }

  private async tryFaceIdUnlock(): Promise<void> {
    try {
      const authInstance = userAuth.getUserAuthInstance({
        challenge: new Uint8Array([5, 6, 7, 8]),
        authType: [userAuth.UserAuthType.FACE],
        authTrustLevel: userAuth.AuthTrustLevel.ATL3
      }, { title: 'Face ID 解锁加密相册' });

      const result = await new Promise<number>((resolve) => {
        authInstance.on('result', {
          onResult(authResult: userAuth.UserAuthResult) {
            resolve(authResult.result);
            authInstance.off('result');
          }
        });
        authInstance.start();
      });

      if (result === 0) {
        router.replaceUrl({ url: 'pages/MainPage' });
      } else {
        this.errorMsg = 'Face ID 未识别，请输入密码';
      }
    } catch {
      this.errorMsg = 'Face ID 不可用，请输入密码';
    }
  }

  private onDigit(d: string): void {
    this.errorMsg = '';
    if (this.inputDigits.length < this.maxLen) {
      this.inputDigits += d;
    }
    if (this.inputDigits.length === this.maxLen) {
      void this.doVerify();
    }
  }

  private onDelete(): void {
    this.errorMsg = '';
    this.inputDigits = this.inputDigits.slice(0, -1);
  }

  private async doVerify(): Promise<void> {
    const valid = await this.store.verifyPassword(this.inputDigits);
    if (valid) {
      await this.recordActivity();
      router.replaceUrl({ url: 'pages/MainPage' });
    } else {
      this.errorMsg = '密码错误，请重试';
      this.inputDigits = '';
      await this.captureIntruderPhoto();
    }
  }

  private async recordActivity(): Promise<void> {
    try {
      const prefs = await dataPreferences.getPreferences(this.getContext(), 'album_security');
      await prefs.put('last_activity_time', Date.now());
      await prefs.put('return_after_unlock', false);
      await prefs.flush();
    } catch {
      // silent
    }
  }

  private async captureIntruderPhoto(): Promise<void> {
    try {
      const enabled = await settingsStore.getIntruderPhotoEnabled();
      if (!enabled) {
        return;
      }
      const result = await cameraPicker.pick(this.getContext(), [cameraPicker.PickerMediaType.PHOTO], { cameraPosition: 0 });
      const resultUri: string = (result as Object as Record<string, string>).resultUri ?? '';
      if (resultUri.length > 0) {
        const record: IntruderRecord = {
          photoPath: resultUri,
          timestamp: Date.now()
        };
        this.intruderRecords.push(record);
        this.saveIntruderRecords();
      }
    } catch (err) {
      console.error('Intruder photo capture failed:', JSON.stringify(err));
    }
  }

  @Builder
  private Mascot() {
    Image($r('app.media.ic_album_mascot_rabbit'))
      .width(122)
      .height(118)
      .objectFit(ImageFit.Contain)
  }

  @Builder
  private PageHeader() {
    Column({ space: 2 }) {
      Text('密码解锁')
        .fontFamily(AlbumTheme.fontFamily)
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor(AlbumTheme.text)
        .width('100%')

      Text('输入密码后进入首页')
        .fontFamily(AlbumTheme.fontFamily)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(AlbumTheme.subText)
        .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private ContentCard() {
    Column({ space: 14 }) {
      this.Mascot()

      Column({ space: 0 }) {
        Text('请输入密码以解锁')
          .fontFamily(AlbumTheme.fontFamily)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(AlbumTheme.subText)
          .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      this.DotRow()

      Text(this.errorMsg || '密码错误时可触发闯入者拍摄')
        .fontFamily(AlbumTheme.fontFamily)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.errorMsg ? '#D85B5B' : AlbumTheme.subText)
        .textAlign(TextAlign.Center)
        .width('100%')

      Column({ space: 18 }) {
        this.KeyRow(['1', '2', '3'])
        this.KeyRow(['4', '5', '6'])
        this.KeyRow(['7', '8', '9'])
        Row({ space: 20 }) {
          if (this.faceIdAvailable && this.faceIdEnabled) {
            Stack() {
              Text('👤')
                .fontFamily(AlbumTheme.fontFamily)
                .fontSize(26)
                .fontWeight(FontWeight.Bold)
                .fontColor(AlbumTheme.text)
            }
            .width(78)
            .height(72)
            .backgroundColor('#E8E1FF')
            .border({ width: AlbumTheme.borderWidth, color: AlbumTheme.line })
            .borderRadius(12)
            .onClick(() => { void this.tryFaceIdUnlock(); })
          } else {
            this.KeyCell('')
          }
          this.KeyCell('0')
          this.DeleteCell()
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .padding({ left: 22, right: 22, top: 24, bottom: 20 })
    .backgroundColor(AlbumTheme.paper)
    .border({ width: AlbumTheme.borderWidth, color: AlbumTheme.line })
    .borderRadius(AlbumTheme.cardRadius)
  }

  @Builder
  private DotRow() {
    Row({ space: 14 }) {
      ForEach(Array.from({ length: this.maxLen }), (_: void, index: number) => {
        Circle()
          .width(24)
          .height(24)
          .fill(index < this.inputDigits.length ? '#A5D8FF' : '#F4E4CF')
          .stroke(AlbumTheme.text)
          .strokeWidth(AlbumTheme.borderWidth)
      }, (_: void, index: number) => index.toString())
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
  }

  @Builder
  private KeyRow(keys: string[]) {
    Row({ space: 16 }) {
      ForEach(keys, (k: string) => {
        this.KeyCell(k)
      }, (k: string) => k)
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private KeyCell(digit: string) {
    Stack() {
      Text(digit)
        .fontFamily(AlbumTheme.fontFamily)
        .fontSize(30)
        .fontWeight(FontWeight.Bold)
        .fontColor(AlbumTheme.text)
    }
    .width(78)
    .height(72)
    .backgroundColor(AlbumTheme.paper)
    .border({ width: AlbumTheme.borderWidth, color: AlbumTheme.line })
    .borderRadius(12)
    .onClick(() => {
      if (digit !== '') {
        this.onDigit(digit);
      }
    })
  }

  @Builder
  private DeleteCell() {
    Stack() {
      Text('⌫')
        .fontFamily(AlbumTheme.fontFamily)
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .fontColor(AlbumTheme.text)
    }
    .width(78)
    .height(72)
    .backgroundColor('#FFE2D8')
    .border({ width: AlbumTheme.borderWidth, color: AlbumTheme.line })
    .borderRadius(12)
    .onClick(() => { this.onDelete(); })
  }

  build() {
    Column({ space: 10 }) {
      this.PageHeader()

      Column() {
        this.ContentCard()
      }
      .layoutWeight(1)
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    }
    .padding({ left: AlbumTheme.screenPadding, right: AlbumTheme.screenPadding, top: 14, bottom: 14 })
    .width('100%')
    .height('100%')
    .backgroundColor(AlbumTheme.pageBg)
  }
}
