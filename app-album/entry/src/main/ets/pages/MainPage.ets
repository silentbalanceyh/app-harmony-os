import router from '@ohos.router';
import { AlbumAccent, AlbumTheme, albumAccentByType } from '../utils/AlbumTheme';
import common from '@ohos.app.ability.common';
import Want from '@ohos.app.ability.Want';
import SoundEffectPlayer from '../utils/SoundEffectPlayer';

interface MenuItem {
  id: string;
  label: string;
  desc: string;
  contentType: string;
  page: string;
}

@Preview
@Entry
@Component
struct MainPage {
  private menuItems: MenuItem[] = [
    { id: 'photos', label: '照片', desc: '目录管理', contentType: 'photo', page: 'pages/PhotosPage' },
    { id: 'videos', label: '视频', desc: '视频目录', contentType: 'video', page: 'pages/VideosPage' },
    { id: 'gifs', label: '动图', desc: 'GIF 收纳', contentType: 'gif', page: 'pages/GifsPage' },
    { id: 'docs', label: '资料', desc: '文档资料', contentType: 'doc', page: 'pages/DocsPage' },
    { id: 'records', label: '录音&文件', desc: '音频文件', contentType: 'record', page: 'pages/RecordsPage' },
    { id: 'settings', label: '设置', desc: '安全配置', contentType: 'settings', page: 'pages/SettingsPage' }
  ];
  private readonly soundEffectPlayer: SoundEffectPlayer = new SoundEffectPlayer();

  private go(page: string): void {
    router.pushUrl({ url: page });
  }

  private getAbilityContext(): common.UIAbilityContext {
    const hostContext = this.getUIContext().getHostContext();
    if (!hostContext) {
      throw new Error('UIAbilityContext is unavailable');
    }
    return hostContext as common.UIAbilityContext;
  }

  private buildCenterWant(): Want {
    return {
      bundleName: 'com.zerows.appcenter',
      moduleName: 'entry',
      abilityName: 'EntryAbility',
      flags: 0x100000,
      parameters: {
        command: 'open-entry',
        starterApp: 'app-album',
        coordinationScene: 'album-back-to-center',
        sourceLabel: '加密相册',
        startedAt: Date.now()
      }
    };
  }

  private async returnToCenter(): Promise<void> {
    await this.soundEffectPlayer.play(this.getAbilityContext(), 'return.wav');
    try {
      await this.getAbilityContext().startAbility(this.buildCenterWant());
    } catch (err) {
      console.error('Return failed: ' + JSON.stringify(err));
    }
  }

  private accentOf(contentType: string): AlbumAccent {
    return albumAccentByType(contentType);
  }

  @Builder
  private Mascot() {
    Image($r('app.media.ic_album_mascot_rabbit'))
      .width(122)
      .height(118)
      .objectFit(ImageFit.Contain)
  }

  @Builder
  private HeaderMascot() {
    Image($r('app.media.ic_album_mascot_rabbit'))
      .width(78)
      .height(78)
      .objectFit(ImageFit.Contain)
  }

  @Builder
  private PageTitle() {
    Text('首页')
      .fontFamily(AlbumTheme.fontFamily)
      .fontSize(28)
      .fontWeight(FontWeight.Bold)
      .fontColor(AlbumTheme.text)
      .layoutWeight(1)
  }

  @Builder
  private PageHeader() {
    Row({ space: 12 }) {
      this.PageTitle()
      this.HeaderMascot()
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private FeatureBadge(item: MenuItem) {
    Stack() {
      Circle()
        .width(76)
        .height(76)
        .fill(this.accentOf(item.contentType).solid)
        .stroke(AlbumTheme.text)
        .strokeWidth(AlbumTheme.borderWidth)

      Text(this.accentOf(item.contentType).icon)
        .fontFamily(AlbumTheme.fontFamily)
        .fontSize(38)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
    }
    .width(76)
    .height(76)
  }

  @Builder
  private FeatureTile(item: MenuItem) {
    Column({ space: 6 }) {
      this.FeatureBadge(item)

      Column({ space: 2 }) {
        Text(item.label)
          .fontFamily(AlbumTheme.fontFamily)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(AlbumTheme.text)
        Text(item.desc)
          .fontFamily(AlbumTheme.fontFamily)
          .fontSize(11)
          .fontColor(AlbumTheme.subText)
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
    }
    .width('100%')
    .height(126)
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Start)
    .padding({ left: 16, right: 16, top: 12, bottom: 10 })
    .backgroundColor(AlbumTheme.paper)
    .border({ width: AlbumTheme.borderWidth, color: AlbumTheme.line })
    .borderRadius(AlbumTheme.cardRadius)
    .onClick(() => { this.go(item.page); })
  }

  build() {
    Column({ space: 8 }) {
      this.PageHeader()

      Grid() {
        ForEach(this.menuItems, (item: MenuItem) => {
          GridItem() {
            this.FeatureTile(item)
          }
        }, (item: MenuItem) => item.id)
      }
      .columnsTemplate('1fr 1fr')
      .rowsTemplate('1fr 1fr 1fr')
      .columnsGap(10)
      .rowsGap(10)
      .height(398)
      .width('100%')

      Text('返回应用中心')
        .fontFamily(AlbumTheme.fontFamily)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(AlbumTheme.text)
        .padding({ left: 18, right: 18, top: 9, bottom: 9 })
        .backgroundColor(AlbumTheme.paleYellow)
        .border({ width: 1.5, color: AlbumTheme.line })
        .borderRadius(AlbumTheme.pillRadius)
        .margin({ top: 8 })
        .onClick(() => {
          void this.returnToCenter();
        })
    }
    .padding({
      left: AlbumTheme.screenPadding,
      right: AlbumTheme.screenPadding,
      top: 14,
      bottom: 14
    })
    .width('100%')
    .height('100%')
    .backgroundColor(AlbumTheme.pageBg)
  }
}
