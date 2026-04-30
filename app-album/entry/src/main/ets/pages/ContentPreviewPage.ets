import router from '@ohos.router';
import fs from '@ohos.file.fs';
import { promptAction } from '@kit.ArkUI';
import { picker } from '@kit.CoreFileKit';
import { getDataManager, MediaDataManager, MediaItem, Folder } from '../models/AlbumData';
import { fileRepo } from '../utils/FileRepoUtil';

interface PreviewRouterParams {
  itemId: string;
  folderId: string;
  contentType: string;
}

@Entry
@Component
struct ContentPreviewPage {
  @State itemId: string = '';
  @State folderId: string = '';
  @State contentType: string = 'photo';
  @State item: MediaItem | null = null;
  @State displayName: string = '';

  private dataManager: MediaDataManager = getDataManager('photo');

  aboutToAppear() {
    const params = router.getParams() as PreviewRouterParams;
    this.itemId = params?.itemId || '';
    this.folderId = params?.folderId || '';
    this.contentType = params?.contentType || 'photo';
    this.dataManager = getDataManager(this.contentType);
    this.loadItem();
  }

  private loadItem(): void {
    const found = this.dataManager.getItemById(this.itemId);
    if (found) {
      this.item = found;
      this.displayName = found.name;
    }
  }

  private getDisplayPath(): string {
    if (!this.item) return '';
    return this.item.privatePath || this.item.uri || '';
  }

  private getTypeLabel(): string {
    switch (this.contentType) {
      case 'video': return '视频';
      case 'gif': return '动图';
      case 'doc': return '文档';
      case 'record': return '录音';
      default: return '照片';
    }
  }

  private getTypeIcon(): string {
    switch (this.contentType) {
      case 'video': return '🎬';
      case 'gif': return '🎭';
      case 'doc': return '📄';
      case 'record': return '🎙️';
      default: return '🖼️';
    }
  }

  private formatSize(bytes: number | undefined): string {
    if (bytes === undefined || bytes === 0) return '未知大小';
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  }

  private formatTime(timestamp: number): string {
    const date = new Date(timestamp);
    return `${date.getFullYear()}-${(date.getMonth() + 1).toString().padStart(2, '0')}-${date.getDate().toString().padStart(2, '0')} ${date.getHours().toString().padStart(2, '0')}:${date.getMinutes().toString().padStart(2, '0')}`;
  }

  private canPreviewImage(): boolean {
    return (this.contentType === 'photo' || this.contentType === 'gif') && !!this.getDisplayPath();
  }

  private handleDelete(): void {
    if (!this.item) return;
    AlertDialog.show({
      title: '删除内容',
      message: `确定要将「${this.item.name}」移入回收站吗？`,
      autoCancel: true,
      alignment: DialogAlignment.Center,
      gridCount: 4,
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '删除',
        fontColor: '#EF4444',
        action: () => {
          this.dataManager.softDeleteItem(this.itemId);
          promptAction.showToast({
            message: '已移入回收站',
            duration: 2000
          });
          router.back();
        }
      }
    });
  }

  private handleRename(): void {
    if (!this.item) return;
    AlertDialog.show({
      title: '重命名',
      message: `当前名称：${this.item.name}`,
      autoCancel: true,
      alignment: DialogAlignment.Center,
      gridCount: 4,
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '确定',
        action: () => {
          const newName = this.displayName.trim();
          if (newName && newName !== this.item!.name) {
            this.dataManager.renameItem(this.itemId, newName);
            this.loadItem();
            promptAction.showToast({ message: '已重命名', duration: 1500 });
          }
        }
      }
    });
  }

  private handleMove(): void {
    if (!this.item) return;
    const allFolders = this.dataManager.getAllFolders().filter(
      (f: Folder) => f.id !== this.folderId && !f.deleteTime
    );
    if (allFolders.length === 0) {
      promptAction.showToast({ message: '没有可移动的目标目录', duration: 2000 });
      return;
    }
    AlertDialog.show({
      title: '移动到目录',
      message: allFolders.map((f: Folder) => f.name).join('\n'),
      autoCancel: true,
      alignment: DialogAlignment.Center,
      gridCount: 4,
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '移动到第一个',
        action: () => {
          this.dataManager.moveItem(this.itemId, allFolders[0].id);
          promptAction.showToast({ message: `已移动到「${allFolders[0].name}」`, duration: 2000 });
          router.back();
        }
      }
    });
  }

  private async handleExport(): Promise<void> {
    const displayPath = this.getDisplayPath();
    if (!displayPath) {
      promptAction.showToast({ message: '无可用文件路径', duration: 2000 });
      return;
    }
    try {
      const documentSaver = new picker.DocumentViewPicker();
      const uris = await documentSaver.save({
        newFileNames: [this.item?.name || 'export']
      });
      if (uris && uris.length > 0) {
        const destUri = uris[0];
        const srcFile = fs.openSync(displayPath, fs.OpenMode.READ_ONLY);
        const destFile = fs.openSync(destUri, fs.OpenMode.READ_WRITE);
        const buffer = new ArrayBuffer(4096);
        let readLen = fs.readSync(srcFile.fd, buffer);
        while (readLen > 0) {
          fs.writeSync(destFile.fd, buffer, { length: readLen });
          readLen = fs.readSync(srcFile.fd, buffer);
        }
        fs.closeSync(srcFile);
        fs.closeSync(destFile);
        promptAction.showToast({ message: '已导出', duration: 2000 });
      }
    } catch {
      promptAction.showToast({ message: '导出失败', duration: 2000 });
    }
  }

  build() {
    Column({ space: 0 }) {
      Row({ space: 12 }) {
        Button('←')
          .width(36).height(36).fontSize(18).fontColor('#111827')
          .backgroundColor('#FFFFFF').borderRadius(18)
          .onClick(() => { router.back(); })
        Text('内容详情')
          .fontSize(20).fontWeight(FontWeight.Bold).fontColor('#111827')
          .layoutWeight(1)
        Button('⋮')
          .width(36).height(36).fontSize(18).fontColor('#111827')
          .backgroundColor(Color.Transparent).borderRadius(18)
          .bindMenu([
            { value: '重命名', action: () => { this.handleRename(); } },
            { value: '移动', action: () => { this.handleMove(); } },
            { value: '导出', action: () => { void this.handleExport(); } },
            { value: '删除', action: () => { this.handleDelete(); } }
          ])
      }
      .width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 })

      if (this.item) {
        Scroll() {
          Column({ space: 16 }) {
            // Preview area
            Column() {
              if (this.canPreviewImage()) {
                Image(this.getDisplayPath())
                  .width('100%')
                  .height('100%')
                  .objectFit(ImageFit.Contain)
              } else if (this.contentType === 'video') {
                Column({ space: 8 }) {
                  Text('🎬').fontSize(48)
                  Text('视频文件').fontSize(14).fontColor('#6B7280')
                  Text('点击右上角菜单导出后用系统播放器打开').fontSize(12).fontColor('#9CA3AF')
                }
              } else if (this.contentType === 'record') {
                Column({ space: 8 }) {
                  Text('🎙️').fontSize(48)
                  Text('音频文件').fontSize(14).fontColor('#6B7280')
                  Text('点击右上角菜单导出后用系统播放器打开').fontSize(12).fontColor('#9CA3AF')
                }
              } else if (this.contentType === 'doc') {
                Column({ space: 8 }) {
                  Text('📄').fontSize(48)
                  Text('文档文件').fontSize(14).fontColor('#6B7280')
                  Text('点击右上角菜单导出后用系统应用打开').fontSize(12).fontColor('#9CA3AF')
                }
              } else {
                Text(this.getTypeIcon())
                  .fontSize(64)
                Text(this.getTypeLabel())
                  .fontSize(16).fontColor('#6B7280').margin({ top: 8 })
              }
            }
            .width('100%')
            .aspectRatio(1)
            .backgroundColor('#F3F6FC')
            .borderRadius(12)
            .justifyContent(FlexAlign.Center)
            .padding(16)

            // Info area
            Column({ space: 0 }) {
              Row() {
                Text('名称').fontSize(14).fontColor('#6B7280')
                Blank()
                Text(this.item!.name)
                  .fontSize(14).fontColor('#111827')
                  .textAlign(TextAlign.End)
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .layoutWeight(1)
                  .margin({ left: 24 })
              }
              .width('100%').padding(16)

              Divider().color('#E5E7EB')

              Row() {
                Text('类型').fontSize(14).fontColor('#6B7280')
                Blank()
                Text(this.getTypeLabel())
                  .fontSize(14).fontColor('#111827')
              }
              .width('100%').padding(16)

              Divider().color('#E5E7EB')

              Row() {
                Text('大小').fontSize(14).fontColor('#6B7280')
                Blank()
                Text(this.formatSize(this.item!.size))
                  .fontSize(14).fontColor('#111827')
              }
              .width('100%').padding(16)

              Divider().color('#E5E7EB')

              Row() {
                Text('创建时间').fontSize(14).fontColor('#6B7280')
                Blank()
                Text(this.formatTime(this.item!.createTime))
                  .fontSize(14).fontColor('#111827')
              }
              .width('100%').padding(16)

              if (this.item!.privatePath) {
                Divider().color('#E5E7EB')
                Row() {
                  Text('存储').fontSize(14).fontColor('#6B7280')
                  Blank()
                  Text('已加密存储')
                    .fontSize(14).fontColor('#10B981')
                }
                .width('100%').padding(16)
              }
            }
            .backgroundColor('#FFFFFF')
            .borderRadius(8)
            .margin({ left: 16, right: 16 })
          }
          .width('100%')
          .padding({ top: 8, bottom: 16 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
      } else {
        Column() {
          Text('内容不存在或已被删除')
            .fontSize(16)
            .fontColor('#999999')
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F3F6FC')
  }
}
