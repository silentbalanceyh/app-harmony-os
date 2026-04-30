import router from '@ohos.router';
import { getDataManager, albumData, MediaDataManager, Folder, MediaItem } from '../models/AlbumData';
import { settingsStore } from '../utils/SettingsStore';
import { userAuth } from '@kit.UserAuthenticationKit';
import { promptAction } from '@kit.ArkUI';
import common from '@ohos.app.ability.common';
import fs from '@ohos.file.fs';
import util from '@ohos.util';

interface SubFolderView {
  id: string;
  name: string;
  itemCount: number;
}

interface ItemView {
  id: string;
  name: string;
  uri?: string;
  privatePath?: string;
  isFavorite: boolean;
  createTime: number;
}

type SortMode = 'time_desc' | 'time_asc' | 'name_asc' | 'name_desc';

interface RouterParams {
  folderId: string;
  folderName: string;
  contentType: string;
}

@CustomDialog
struct FolderNameDialog {
  controller: CustomDialogController;
  title: string = '';
  initialValue: string = '';
  @State inputValue: string = '';
  @State validationMsg: string = '';
  onConfirm: (value: string) => void = () => {};
  private maxLength: number = 30;

  aboutToAppear() {
    this.inputValue = this.initialValue;
  }

  private validate(): boolean {
    const trimmed = this.inputValue.trim();
    if (!trimmed) {
      this.validationMsg = '名称不能为空';
      return false;
    }
    if (trimmed.length > this.maxLength) {
      this.validationMsg = `名称不能超过${this.maxLength}个字符`;
      return false;
    }
    return true;
  }

  build() {
    Column({ space: 16 }) {
      Text(this.title)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#111827')

      TextInput({ text: this.inputValue, placeholder: '请输入名称' })
        .fontSize(16)
        .width('100%')
        .height(44)
        .borderRadius(8)
        .onChange((value: string) => {
          this.inputValue = value;
          this.validationMsg = '';
        })

      if (this.validationMsg) {
        Text(this.validationMsg)
          .fontSize(12)
          .fontColor('#EF4444')
          .width('100%')
      }

      Row({ space: 12 }) {
        Button('取消')
          .fontSize(14)
          .fontColor('#6B7280')
          .backgroundColor('#F3F4F6')
          .borderRadius(8)
          .layoutWeight(1)
          .onClick(() => { this.controller.close(); })

        Button('确定')
          .fontSize(14)
          .fontColor('#FFFFFF')
          .backgroundColor('#6366F1')
          .borderRadius(8)
          .layoutWeight(1)
          .onClick(() => {
            if (this.validate()) {
              this.onConfirm(this.inputValue.trim());
              this.controller.close();
            }
          })
      }
      .width('100%')
    }
    .padding(24)
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
  }
}

@Entry
@Component
struct FolderDetailPage {
  @State folderId: string = '';
  @State folderName: string = '';
  @State contentType: string = 'photo';
  @State subFolders: SubFolderView[] = [];
  @State items: ItemView[] = [];
  @State selectMode: boolean = false;
  @State selectedIds: Set<string> = new Set();
  @State searchQuery: string = '';
  @State sortMode: SortMode = 'time_desc';
  @State filterFavorite: boolean = false;

  private dataManager: MediaDataManager = albumData;
  private newFolderDialogController: CustomDialogController | null = null;
  private renameDialogController: CustomDialogController | null = null;
  private favoritesStore: Set<string> = new Set();

  aboutToAppear() {
    const params = router.getParams() as RouterParams;
    this.folderId = params?.folderId || '';
    this.folderName = params?.folderName || '目录';
    this.contentType = params?.contentType || 'photo';
    this.dataManager = getDataManager(this.contentType);
    this.loadFavorites();
    void this.checkFolderFaceId();
    this.loadData();
  }

  private loadFavorites(): void {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const path = context.filesDir + '/favorites.json';
      if (fs.accessSync(path)) {
        const file = fs.openSync(path, fs.OpenMode.READ_ONLY);
        const stat = fs.statSync(path);
        const buf = new ArrayBuffer(stat.size);
        fs.readSync(file.fd, buf);
        fs.closeSync(file);
        const decoder = util.TextDecoder.create('utf-8');
        const content = decoder.decodeToString(new Uint8Array(buf));
        const data = JSON.parse(content) as string[];
        this.favoritesStore = new Set(data);
      }
    } catch {
      this.favoritesStore = new Set();
    }
  }

  private saveFavorites(): void {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const path = context.filesDir + '/favorites.json';
      const file = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
      const encoder = new util.TextEncoder();
      const data = encoder.encodeInto(JSON.stringify(Array.from(this.favoritesStore)));
      fs.writeSync(file.fd, data.buffer);
      fs.closeSync(file);
    } catch {
      // silent
    }
  }

  private toggleFavorite(itemId: string): void {
    if (this.favoritesStore.has(itemId)) {
      this.favoritesStore.delete(itemId);
    } else {
      this.favoritesStore.add(itemId);
    }
    this.saveFavorites();
    this.loadData();
  }

  private async checkFolderFaceId(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      await settingsStore.init(context);
      const folderAccess = await settingsStore.getFolderFaceIdAccess();
      if (!folderAccess) return;

      const authInstance = userAuth.getUserAuthInstance({
        challenge: new Uint8Array([9, 10, 11, 12]),
        authType: [userAuth.UserAuthType.FACE],
        authTrustLevel: userAuth.AuthTrustLevel.ATL3
      }, { title: '验证 Face ID 以访问文件夹' });

      await new Promise<void>((resolve, reject) => {
        authInstance.on('result', {
          onResult(result: userAuth.UserAuthResult) {
            authInstance.off('result');
            if (result.result === 0) {
              resolve();
            } else {
              reject(new Error('Face ID auth failed'));
            }
          }
        });
        authInstance.start();
      });
    } catch {
      router.back();
    }
  }

  loadData() {
    const rawSubFolders: Folder[] = this.dataManager.getSubFolders(this.folderId);
    this.subFolders = rawSubFolders.map((f: Folder): SubFolderView => ({
      id: f.id,
      name: f.name,
      itemCount: this.dataManager.getItemsInFolder(f.id).length
    }));

    let rawItems: MediaItem[] = this.dataManager.getItemsInFolder(this.folderId);

    // Filter by search
    if (this.searchQuery.trim()) {
      const q = this.searchQuery.trim().toLowerCase();
      rawItems = rawItems.filter(item => item.name.toLowerCase().includes(q));
    }

    // Filter by favorite
    if (this.filterFavorite) {
      rawItems = rawItems.filter(item => this.favoritesStore.has(item.id));
    }

    // Sort
    rawItems = this.sortItems(rawItems);

    this.items = rawItems.map((p: MediaItem): ItemView => ({
      id: p.id,
      name: p.name,
      uri: p.uri,
      privatePath: p.privatePath,
      isFavorite: this.favoritesStore.has(p.id),
      createTime: p.createTime
    }));
  }

  private sortItems(items: MediaItem[]): MediaItem[] {
    const sorted = items.slice();
    switch (this.sortMode) {
      case 'time_desc':
        sorted.sort((a, b) => b.createTime - a.createTime);
        break;
      case 'time_asc':
        sorted.sort((a, b) => a.createTime - b.createTime);
        break;
      case 'name_asc':
        sorted.sort((a, b) => a.name.localeCompare(b.name));
        break;
      case 'name_desc':
        sorted.sort((a, b) => b.name.localeCompare(a.name));
        break;
    }
    return sorted;
  }

  private getSortLabel(): string {
    switch (this.sortMode) {
      case 'time_desc': return '最新优先';
      case 'time_asc': return '最早优先';
      case 'name_asc': return '名称 A-Z';
      case 'name_desc': return '名称 Z-A';
    }
  }

  showNewFolderDialog() {
    this.newFolderDialogController = new CustomDialogController({
      builder: FolderNameDialog({
        title: '新建子目录',
        initialValue: '',
        onConfirm: (value: string) => {
          if (this.dataManager.isFolderNameDuplicate(value, this.folderId)) {
            return;
          }
          this.dataManager.addFolder(value, this.folderId);
          this.loadData();
        }
      }),
      autoCancel: true,
      alignment: DialogAlignment.Center,
      customStyle: true
    });
    this.newFolderDialogController.open();
  }

  showRenameDialog() {
    this.renameDialogController = new CustomDialogController({
      builder: FolderNameDialog({
        title: '重命名目录',
        initialValue: this.folderName,
        onConfirm: (value: string) => {
          if (this.dataManager.isFolderNameDuplicate(value, this.folderId, this.folderId)) {
            return;
          }
          this.dataManager.renameFolder(this.folderId, value);
          this.folderName = value;
        }
      }),
      autoCancel: true,
      alignment: DialogAlignment.Center,
      customStyle: true
    });
    this.renameDialogController.open();
  }

  showDeleteDialog() {
    AlertDialog.show({
      title: '删除目录',
      message: '删除后目录将移入回收站，可在回收站中恢复。',
      autoCancel: true,
      alignment: DialogAlignment.Center,
      gridCount: 4,
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: {
        value: '删除',
        fontColor: '#FF0000',
        action: () => {
          this.dataManager.softDeleteFolder(this.folderId);
          router.back();
        }
      }
    });
  }

  private enterSelectMode(): void {
    this.selectMode = true;
    this.selectedIds = new Set();
  }

  private exitSelectMode(): void {
    this.selectMode = false;
    this.selectedIds = new Set();
  }

  private toggleSelect(id: string): void {
    if (this.selectedIds.has(id)) {
      this.selectedIds.delete(id);
    } else {
      this.selectedIds.add(id);
    }
    if (this.selectedIds.size === 0) {
      this.selectMode = false;
    }
  }

  private selectAll(): void {
    this.items.forEach(item => this.selectedIds.add(item.id));
  }

  private batchDelete(): void {
    if (this.selectedIds.size === 0) return;
    AlertDialog.show({
      title: '批量删除',
      message: `确定要将选中的 ${this.selectedIds.size} 项移入回收站吗？`,
      autoCancel: true,
      alignment: DialogAlignment.Center,
      gridCount: 4,
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: {
        value: '删除',
        fontColor: '#EF4444',
        action: () => {
          this.selectedIds.forEach(id => this.dataManager.softDeleteItem(id));
          this.exitSelectMode();
          this.loadData();
          promptAction.showToast({ message: '已移入回收站', duration: 1500 });
        }
      }
    });
  }

  private batchMove(): void {
    if (this.selectedIds.size === 0) return;
    const allFolders = this.dataManager.getAllFolders().filter(
      (f: Folder) => f.id !== this.folderId && !f.deleteTime
    );
    if (allFolders.length === 0) {
      promptAction.showToast({ message: '没有可移动的目标目录', duration: 2000 });
      return;
    }
    AlertDialog.show({
      title: '批量移动',
      message: `将 ${this.selectedIds.size} 项移动到「${allFolders[0].name}」？`,
      autoCancel: true,
      alignment: DialogAlignment.Center,
      gridCount: 4,
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: {
        value: '移动',
        fontColor: '#6366F1',
        action: () => {
          this.selectedIds.forEach(id => this.dataManager.moveItem(id, allFolders[0].id));
          this.exitSelectMode();
          this.loadData();
          promptAction.showToast({ message: `已移动到「${allFolders[0].name}」`, duration: 1500 });
        }
      }
    });
  }

  handleOpenSubFolder(folder: SubFolderView) {
    router.pushUrl({
      url: 'pages/FolderDetailPage',
      params: { folderId: folder.id, folderName: folder.name, contentType: this.contentType }
    });
  }

  handleImport() {
    router.pushUrl({
      url: 'pages/ImportGuidePage',
      params: { folderId: this.folderId, folderName: this.folderName, contentType: this.contentType }
    });
  }

  getItemInitials(name: string): string {
    return name.substring(0, 2).toUpperCase();
  }

  getItemBgColor(): ResourceColor {
    switch (this.contentType) {
      case 'video': return '#EC4899';
      case 'gif': return '#F59E0B';
      case 'doc': return '#10B981';
      case 'record': return '#3B82F6';
      default: return '#4A90E2';
    }
  }

  getImportLabel(): string {
    switch (this.contentType) {
      case 'video': return '导入视频';
      case 'gif': return '导入动图';
      case 'doc': return '导入资料';
      case 'record': return '导入文件';
      default: return '导入照片';
    }
  }

  build() {
    Column() {
      // Top bar
      Row() {
        Button({ type: ButtonType.Normal }) {
          Text(this.selectMode ? '✕' : '←')
            .fontSize(24).fontColor('#333333')
        }
        .backgroundColor(Color.Transparent).width(48).height(48)
        .onClick(() => {
          if (this.selectMode) { this.exitSelectMode(); }
          else { router.back(); }
        })

        if (this.selectMode) {
          Text(`已选 ${this.selectedIds.size} 项`)
            .fontSize(18).fontWeight(FontWeight.Medium).layoutWeight(1).textAlign(TextAlign.Center)
        } else {
          Text(this.folderName)
            .fontSize(18).fontWeight(FontWeight.Medium).layoutWeight(1).textAlign(TextAlign.Center)
        }

        Button({ type: ButtonType.Normal }) {
          Text('⋮').fontSize(24).fontColor('#333333')
        }
        .backgroundColor(Color.Transparent).width(48).height(48)
        .bindMenu([
          { value: '选择', action: () => { this.enterSelectMode(); } },
          { value: '新建子目录', action: () => { this.showNewFolderDialog(); } },
          { value: this.getImportLabel(), action: () => { this.handleImport(); } },
          { value: '重命名目录', action: () => { this.showRenameDialog(); } },
          { value: '删除目录', action: () => { this.showDeleteDialog(); } }
        ])
      }
      .width('100%').height(56).padding({ left: 8, right: 8 }).backgroundColor('#F5F5F5')

      // Search & filter bar
      if (!this.selectMode && (this.subFolders.length > 0 || this.items.length > 0)) {
        Row({ space: 8 }) {
          TextInput({ text: this.searchQuery, placeholder: '搜索' })
            .fontSize(14).height(36).layoutWeight(1).borderRadius(8)
            .onChange((value: string) => {
              this.searchQuery = value;
              this.loadData();
            })

          Text(this.filterFavorite ? '★' : '☆')
            .fontSize(20).fontColor(this.filterFavorite ? '#F59E0B' : '#9CA3AF')
            .padding({ left: 8, right: 8 })
            .onClick(() => {
              this.filterFavorite = !this.filterFavorite;
              this.loadData();
            })

          Text(this.getSortLabel())
            .fontSize(12).fontColor('#6366F1')
            .padding({ left: 6, right: 6, top: 4, bottom: 4 })
            .backgroundColor('#EEF2FF').borderRadius(4)
            .bindMenu([
              { value: '最新优先', action: () => { this.sortMode = 'time_desc'; this.loadData(); } },
              { value: '最早优先', action: () => { this.sortMode = 'time_asc'; this.loadData(); } },
              { value: '名称 A-Z', action: () => { this.sortMode = 'name_asc'; this.loadData(); } },
              { value: '名称 Z-A', action: () => { this.sortMode = 'name_desc'; this.loadData(); } }
            ])
        }
        .width('100%').padding({ left: 16, right: 16, top: 8, bottom: 8 })
      }

      // Batch action bar
      if (this.selectMode) {
        Row({ space: 12 }) {
          Text('全选').fontSize(14).fontColor('#6366F1')
            .onClick(() => { this.selectAll(); })
          Blank()
          Text('移动').fontSize(14).fontColor('#6366F1')
            .onClick(() => { this.batchMove(); })
          Text('删除').fontSize(14).fontColor('#EF4444')
            .onClick(() => { this.batchDelete(); })
        }
        .width('100%').padding({ left: 16, right: 16, top: 8, bottom: 8 })
        .backgroundColor('#FAFAFA')
      }

      // Content
      if (this.subFolders.length === 0 && this.items.length === 0) {
        Column() {
          Text('暂无内容').fontSize(16).fontColor('#999999').margin({ bottom: 8 })
          Text('点击右上角菜单新建子目录或导入').fontSize(14).fontColor('#CCCCCC')
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column() {
            if (this.subFolders.length > 0) {
              Column() {
                Text('子目录').fontSize(14).fontColor('#666666')
                  .width('100%').padding({ left: 16, top: 12, bottom: 8 })

                List({ space: 0 }) {
                  ForEach(this.subFolders, (folder: SubFolderView) => {
                    ListItem() {
                      Row() {
                        Text('📁').fontSize(24).margin({ right: 12 })
                        Column() {
                          Text(folder.name).fontSize(16).fontColor('#333333')
                          Text(`${folder.itemCount} 项`).fontSize(12).fontColor('#999999').margin({ top: 4 })
                        }
                        .alignItems(HorizontalAlign.Start).layoutWeight(1)
                        Text('›').fontSize(24).fontColor('#CCCCCC')
                      }
                      .width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 })
                      .onClick(() => { this.handleOpenSubFolder(folder); })
                    }
                  })
                }
                .divider({ strokeWidth: 1, color: '#F0F0F0', startMargin: 60, endMargin: 16 })
              }
              .margin({ bottom: 16 })
            }

            if (this.items.length > 0) {
              Column() {
                Text('内容').fontSize(14).fontColor('#666666')
                  .width('100%').padding({ left: 16, top: 12, bottom: 8 })

                Grid() {
                  ForEach(this.items, (item: ItemView) => {
                    GridItem() {
                      Stack() {
                        Column() {
                          if (item.privatePath) {
                            Image(item.privatePath).width('100%').height('100%')
                              .objectFit(ImageFit.Cover).borderRadius(8)
                          } else if (item.uri) {
                            Image(item.uri).width('100%').height('100%')
                              .objectFit(ImageFit.Cover).borderRadius(8)
                          } else {
                            Text(this.getItemInitials(item.name))
                              .fontSize(20).fontColor(Color.White).fontWeight(FontWeight.Bold)
                          }
                        }
                        .width('100%').aspectRatio(1)
                        .backgroundColor(this.getItemBgColor())
                        .borderRadius(8).justifyContent(FlexAlign.Center).clip(true)

                        // Favorite badge
                        if (item.isFavorite) {
                          Text('★')
                            .fontSize(14).fontColor('#F59E0B')
                            .position({ x: 2, y: 2 })
                        }

                        // Selection check
                        if (this.selectMode) {
                          Stack() {
                            Circle().width(22).height(22)
                              .fill(this.selectedIds.has(item.id) ? '#6366F1' : '#FFFFFFCC')
                              .stroke('#6366F1').strokeWidth(2)
                            if (this.selectedIds.has(item.id)) {
                              Text('✓').fontSize(12).fontColor('#FFFFFF').fontWeight(FontWeight.Bold)
                            }
                          }
                          .position({ x: '75%', y: 4 })
                        }
                      }
                    }
                    .onClick(() => {
                      if (this.selectMode) {
                        this.toggleSelect(item.id);
                      } else {
                        router.pushUrl({
                          url: 'pages/ContentPreviewPage',
                          params: { itemId: item.id, folderId: this.folderId, contentType: this.contentType }
                        });
                      }
                    })
                    .gesture(
                      LongPressGesture()
                        .onAction(() => {
                          if (!this.selectMode) {
                            this.enterSelectMode();
                            this.toggleSelect(item.id);
                          }
                        })
                    )
                  })
                }
                .columnsTemplate('1fr 1fr 1fr')
                .columnsGap(8).rowsGap(8)
                .padding({ left: 16, right: 16 })
              }
            }
          }
          .width('100%')
        }
        .layoutWeight(1).scrollBar(BarState.Auto)
      }
    }
    .width('100%').height('100%').backgroundColor(Color.White)
  }
}
