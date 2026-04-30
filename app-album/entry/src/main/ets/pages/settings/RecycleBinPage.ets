import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import { albumData, videoData, gifData, docData, recordData, MediaItem, DeletedFolder } from '../../models/AlbumData';

interface RecycleItem {
  id: string;
  name: string;
  typeLabel: string;
  managerIndex: number;
  isFolder: boolean;
  itemCount: number;
}

@Preview
@Entry
@Component
struct RecycleBinPage {
  @State items: RecycleItem[] = [];

  aboutToAppear(): void {
    this.loadItems();
  }

  private readonly THIRTY_DAYS_MS: number = 30 * 24 * 60 * 60 * 1000;

  loadItems(): void {
    const managers = [albumData, videoData, gifData, docData, recordData];
    const typeLabels = ['照片', '视频', '动图', '资料', '录音'];
    const result: RecycleItem[] = [];
    const now = Date.now();
    let autoCleaned = 0;

    managers.forEach((mgr, idx) => {
      // Auto-clean expired items
      const deleted = mgr.getDeletedItems();
      const expired = deleted.filter((item: MediaItem) => item.deleteTime && (now - item.deleteTime) > this.THIRTY_DAYS_MS);
      expired.forEach((item: MediaItem) => mgr.permanentlyDeleteItem(item.id));
      if (expired.length > 0) {
        autoCleaned += expired.length;
      }

      // Auto-clean expired folders
      const deletedFolders = mgr.getDeletedFolders();
      const expiredFolders = deletedFolders.filter((df: DeletedFolder) =>
        df.folder.deleteTime && (now - df.folder.deleteTime) > this.THIRTY_DAYS_MS
      );
      expiredFolders.forEach((df: DeletedFolder) => mgr.permanentlyDeleteFolder(df.folder.id));
      autoCleaned += expiredFolders.length;

      // Add deleted folders first
      mgr.getDeletedFolders().forEach((df: DeletedFolder) => {
        result.push({
          id: df.folder.id,
          name: df.folder.name,
          typeLabel: typeLabels[idx],
          managerIndex: idx,
          isFolder: true,
          itemCount: df.itemCount
        });
      });

      // Add deleted items (exclude items belonging to deleted folders)
      const folderIds = new Set(mgr.getDeletedFolders().map(df => df.folder.id));
      mgr.getDeletedItems().forEach((item: MediaItem) => {
        if (!folderIds.has(item.folderId)) {
          result.push({
            id: item.id,
            name: item.name,
            typeLabel: typeLabels[idx],
            managerIndex: idx,
            isFolder: false,
            itemCount: 0
          });
        }
      });
    });

    this.items = result;

    if (autoCleaned > 0) {
      promptAction.showToast({
        message: `已自动清理 ${autoCleaned} 个超过30天的项目`,
        duration: 2000
      });
    }
  }

  private getManager(index: number) {
    const managers = [albumData, videoData, gifData, docData, recordData];
    return managers[index];
  }

  handleRestore(item: RecycleItem): void {
    const mgr = this.getManager(item.managerIndex);
    if (item.isFolder) {
      mgr.restoreFolder(item.id);
    } else {
      mgr.restoreItem(item.id);
    }
    this.loadItems();
    promptAction.showToast({
      message: `已恢复: ${item.name}`,
      duration: 2000
    });
  }

  handleDelete(item: RecycleItem): void {
    const mgr = this.getManager(item.managerIndex);
    if (item.isFolder) {
      mgr.permanentlyDeleteFolder(item.id);
    } else {
      mgr.permanentlyDeleteItem(item.id);
    }
    this.loadItems();
    promptAction.showToast({
      message: `已永久删除: ${item.name}`,
      duration: 2000
    });
  }

  handleClearAll(): void {
    if (this.items.length === 0) {
      return;
    }
    AlertDialog.show({
      title: '清空回收站',
      message: '确定要永久删除所有回收站中的项目吗？此操作不可恢复。',
      autoCancel: true,
      alignment: DialogAlignment.Center,
      gridCount: 4,
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '清空',
        fontColor: '#EF4444',
        action: () => {
          const managers = [albumData, videoData, gifData, docData, recordData];
          managers.forEach(mgr => mgr.clearRecycleBin());
          this.loadItems();
          promptAction.showToast({
            message: '回收站已清空',
            duration: 2000
          });
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
        Text('回收站')
          .fontSize(20).fontWeight(FontWeight.Bold).fontColor('#111827')
        Blank()
        Text('清空')
          .fontSize(14).fontColor(this.items.length === 0 ? '#9CA3AF' : '#EF4444')
          .onClick(() => { this.handleClearAll(); })
      }
      .width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 })

      if (this.items.length === 0) {
        Column() {
          Text('🗑️').fontSize(48)
          Text('回收站为空').fontSize(16).fontColor('#6B7280').margin({ top: 12 })
          Text('删除的文件会在这里保留30天').fontSize(13).fontColor('#9CA3AF').margin({ top: 4 })
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        List({ space: 8 }) {
          ForEach(this.items, (item: RecycleItem) => {
            ListItem() {
              Row({ space: 12 }) {
                Text(item.isFolder ? '📁' : '📄')
                  .fontSize(24)

                Column({ space: 2 }) {
                  Text(item.name).fontSize(14).fontColor('#111827')
                  Text(item.isFolder
                    ? `${item.typeLabel} · ${item.itemCount} 项`
                    : item.typeLabel
                  ).fontSize(12).fontColor('#9CA3AF')
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                Text('恢复')
                  .fontSize(13).fontColor('#6366F1')
                  .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                  .onClick(() => { this.handleRestore(item); })

                Text('删除')
                  .fontSize(13).fontColor('#EF4444')
                  .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                  .onClick(() => { this.handleDelete(item); })
              }
              .width('100%').padding(16).backgroundColor('#FFFFFF').borderRadius(8)
            }
          }, (item: RecycleItem) => item.id + (item.isFolder ? '_folder' : '_item'))
        }
        .width('100%').layoutWeight(1).padding({ left: 16, right: 16 })
      }
    }
    .width('100%').height('100%').backgroundColor('#F3F6FC')
  }
}
