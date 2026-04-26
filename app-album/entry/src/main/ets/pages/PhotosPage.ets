import router from '@ohos.router';
import { albumData, Folder } from '../models/AlbumData';
import { AlbumAccent, AlbumTheme, albumAccentByType, albumImportTitle, albumTypeLabel } from '../utils/AlbumTheme';

@Preview
@Entry
@Component
struct PhotosPage {
  @State rootFolders: Folder[] = [];
  @State menuVisible: boolean = false;

  private accent(): AlbumAccent {
    return albumAccentByType('photo');
  }

  aboutToAppear(): void {
    albumData.init(getContext(this));
    this.loadRootFolders();
  }

  private loadRootFolders(): void {
    this.rootFolders = albumData.getRootFolders();
  }

  private getCount(folderId: string): number {
    return albumData.getSubFolders(folderId).length + albumData.getPhotosInFolder(folderId).length;
  }

  private openFolder(folder: Folder): void {
    router.pushUrl({
      url: 'pages/FolderDetailPage',
      params: {
        folderId: folder.id,
        folderName: folder.name,
        contentType: 'photo'
      }
    });
  }

  private goImport(): void {
    this.menuVisible = false;
    router.pushUrl({
      url: 'pages/ImportGuidePage',
      params: {
        folderId: '',
        folderName: '主目录',
        contentType: 'photo'
      }
    });
  }

  private createRootFolder(): void {
    this.menuVisible = false;
    albumData.addFolder(`照片目录 ${this.rootFolders.length + 1}`, '');
    this.loadRootFolders();
  }

  @Builder
  private Header() {
    Row({ space: 14 }) {
      Stack() {
        Text('←')
          .fontFamily(AlbumTheme.fontFamily)
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(AlbumTheme.line)
      }
      .width(42)
      .height(42)
      .backgroundColor(AlbumTheme.paper)
      .border({ width: AlbumTheme.borderWidth, color: AlbumTheme.line })
      .borderRadius(22)
      .onClick(() => { router.back(); })

      Text('照片')
        .fontFamily(AlbumTheme.fontFamily)
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor(AlbumTheme.text)
        .layoutWeight(1)

      this.PlusButton()
    }
    .width('100%')
  }

  @Builder
  private PlusButton() {
    Stack() {
      Text('+')
        .fontFamily(AlbumTheme.fontFamily)
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor(AlbumTheme.text)
    }
    .width(42)
    .height(42)
    .backgroundColor(AlbumTheme.paper)
    .border({ width: AlbumTheme.borderWidth, color: AlbumTheme.line })
    .borderRadius(22)
    .bindMenu(this.menuVisible, [
      {
        value: '新建目录',
        action: () => {
          this.createRootFolder();
        }
      },
      {
        value: albumImportTitle('photo'),
        action: () => {
          this.goImport();
        }
      }
    ])
    .onClick(() => {
      this.menuVisible = true;
    })
  }

  @Builder
  private Hero(accent: AlbumAccent) {
    Row() {
      Column({ space: 6 }) {
        Text(`${albumTypeLabel('photo')}目录`)
          .fontFamily(AlbumTheme.fontFamily)
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(AlbumTheme.text)
        Text('右上角 + 展开后可新建目录或导入')
          .fontFamily(AlbumTheme.fontFamily)
          .fontSize(14)
          .fontColor(AlbumTheme.subText)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 22, right: 22, top: 22, bottom: 22 })
    .backgroundColor(accent.tint)
    .border({ width: AlbumTheme.borderWidth, color: AlbumTheme.line })
    .borderRadius(AlbumTheme.cardRadius)
  }

  @Builder
  private FolderRow(folder: Folder, index: number) {
    Row({ space: 16 }) {
      Stack() {
        Text('▣')
          .fontFamily(AlbumTheme.fontFamily)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
      }
      .width(52)
      .height(42)
      .backgroundColor(index % 3 === 0 ? '#FFD166' : index % 3 === 1 ? '#78D6B5' : '#6C8DFF')
      .border({ width: AlbumTheme.borderWidth, color: AlbumTheme.line })
      .borderRadius(10)

      Column({ space: 4 }) {
        Text(folder.name)
          .fontFamily(AlbumTheme.fontFamily)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(AlbumTheme.text)
        Text(`${this.getCount(folder.id)} 项`)
          .fontFamily(AlbumTheme.fontFamily)
          .fontSize(13)
          .fontColor(AlbumTheme.subText)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text('›')
        .fontFamily(AlbumTheme.fontFamily)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(AlbumTheme.text)
    }
    .width('100%')
    .padding({ left: 20, right: 18, top: 18, bottom: 18 })
    .backgroundColor(AlbumTheme.paper)
    .border({ width: AlbumTheme.borderWidth, color: AlbumTheme.line })
    .borderRadius(AlbumTheme.cardRadius)
    .onClick(() => { this.openFolder(folder); })
  }

  @Builder
  private Empty(accent: AlbumAccent) {
    Column({ space: 14 }) {
      Text(accent.emptyIcon)
        .fontFamily(AlbumTheme.fontFamily)
        .fontSize(56)
        .fontWeight(FontWeight.Bold)
        .fontColor(AlbumTheme.text)
      Text('暂无目录')
        .fontFamily(AlbumTheme.fontFamily)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(AlbumTheme.text)
      Text('点击右上角 + 创建目录')
        .fontFamily(AlbumTheme.fontFamily)
        .fontSize(14)
        .fontColor(AlbumTheme.subText)
    }
    .width('100%')
    .padding({ top: 34, bottom: 34 })
    .backgroundColor(AlbumTheme.paper)
    .border({ width: AlbumTheme.borderWidth, color: AlbumTheme.line })
    .borderRadius(AlbumTheme.cardRadius)
  }

  build() {
    Scroll() {
      Column({ space: 18 }) {
        this.Header()
        this.Hero(this.accent())

        if (this.rootFolders.length === 0) {
          this.Empty(this.accent())
        } else {
          Column({ space: 14 }) {
            ForEach(this.rootFolders, (folder: Folder, index: number) => {
              this.FolderRow(folder, index)
            }, (folder: Folder) => folder.id)
          }
          .width('100%')
        }
      }
      .padding({
        left: AlbumTheme.screenPadding,
        right: AlbumTheme.screenPadding,
        top: AlbumTheme.titleTop,
        bottom: 28
      })
      .width('100%')
    }
    .scrollBar(BarState.Off)
    .width('100%')
    .height('100%')
    .backgroundColor(AlbumTheme.pageBg)
  }
}
