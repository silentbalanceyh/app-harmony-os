import common from '@ohos.app.ability.common';
import { PasswordStore } from '../utils/PasswordStore';
import router from '@ohos.router';
import { AlbumTheme } from '../utils/AlbumTheme';

@Preview
@Entry
@Component
struct PasswordSetup {
  @State inputDigits: string = '';
  @State confirmDigits: string = '';
  @State step: number = 0;
  @State errorMsg: string = '';
  private store: PasswordStore = new PasswordStore();
  private maxLen: number = 6;

  private getContext(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  async aboutToAppear(): Promise<void> {
    await this.store.init(this.getContext());
  }

  private onDigit(d: string): void {
    this.errorMsg = '';
    if (this.step === 0) {
      if (this.inputDigits.length < this.maxLen) {
        this.inputDigits += d;
      }
    } else if (this.confirmDigits.length < this.maxLen) {
      this.confirmDigits += d;
    }
  }

  private onDelete(): void {
    this.errorMsg = '';
    if (this.step === 0) {
      this.inputDigits = this.inputDigits.slice(0, -1);
    } else {
      this.confirmDigits = this.confirmDigits.slice(0, -1);
    }
  }

  private async onConfirm(): Promise<void> {
    if (this.step === 0) {
      if (this.inputDigits.length < 4) {
        this.errorMsg = '密码至少4位';
        return;
      }
      this.step = 1;
      this.errorMsg = '';
      return;
    }

    if (this.inputDigits !== this.confirmDigits) {
      this.errorMsg = '两次密码不一致';
      this.confirmDigits = '';
      return;
    }
    await this.store.setPassword(this.inputDigits);
    router.replaceUrl({ url: 'pages/MainPage' });
  }

  private currentLen(): number {
    return this.step === 0 ? this.inputDigits.length : this.confirmDigits.length;
  }

  private async afterDigit(): Promise<void> {
    const len = this.currentLen();
    if (len === this.maxLen) {
      await this.onConfirm();
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
      Text(this.step === 0 ? '设置密码' : '确认密码')
        .fontFamily(AlbumTheme.fontFamily)
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor(AlbumTheme.text)
        .width('100%')

      Text('完成后进入加密相册首页')
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
        Text(this.step === 0 ? '设置访问密码' : '确认访问密码')
          .fontFamily(AlbumTheme.fontFamily)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(AlbumTheme.subText)
          .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      this.DotRow()

      Text(this.errorMsg || (this.step === 0 ? '用于保护照片、视频、资料与录音目录' : '确认后进入私密相册'))
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
          this.KeyCell('')
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
          .fill(index < this.currentLen() ? '#A5D8FF' : '#F4E4CF')
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
        void this.afterDigit();
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
