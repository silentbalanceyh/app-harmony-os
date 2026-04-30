import { preferences } from '@kit.ArkData';
import { Context } from '@kit.AbilityKit';
import { fileRepo } from '../utils/FileRepoUtil';

export interface MediaItem {
  id: string;
  name: string;
  createTime: number;
  folderId: string;
  uri?: string;
  privatePath?: string;
  originalFileName?: string;
  size?: number;
  deleteTime?: number;
}

export interface Photo extends MediaItem {}

export interface Folder {
  id: string;
  name: string;
  parentId: string;
  createTime: number;
  deleteTime?: number;
  originalParentId?: string;
}

export interface DeletedFolder {
  folder: Folder;
  itemCount: number;
}

@ObservedV2
export class MediaDataManager {
  @Trace folders: Folder[] = [];
  @Trace items: MediaItem[] = [];
  @Trace deletedItems: MediaItem[] = [];
  @Trace deletedFolders: DeletedFolder[] = [];

  private preferencesStore: preferences.Preferences | null = null;
  private contentType: string = '';
  private preferencesName: string = '';

  constructor(contentType: string, preferencesName: string) {
    this.contentType = contentType;
    this.preferencesName = preferencesName;
  }

  async init(context: Context): Promise<void> {
    try {
      this.preferencesStore = await preferences.getPreferences(context, this.preferencesName);
      await this.loadData();
    } catch (err) {
      console.error(`[MediaData:${this.contentType}] Failed to init:`, JSON.stringify(err));
    }
  }

  private generateId(): string {
    return Date.now().toString() + Math.random().toString(36).substring(2, 9);
  }

  getRootFolders(): Folder[] {
    return this.folders.filter(folder => folder.parentId === '' && !folder.deleteTime);
  }

  getSubFolders(parentId: string): Folder[] {
    return this.folders.filter(folder => folder.parentId === parentId && !folder.deleteTime);
  }

  getItemsInFolder(folderId: string): MediaItem[] {
    return this.items.filter(item => item.folderId === folderId && !item.deleteTime);
  }

  addFolder(name: string, parentId: string): Folder {
    const newFolder: Folder = {
      id: this.generateId(),
      name: name,
      parentId: parentId,
      createTime: Date.now()
    };
    this.folders.push(newFolder);
    this.saveData();
    return newFolder;
  }

  addItem(name: string, folderId: string, uri?: string, size?: number,
    privatePath?: string, originalFileName?: string): MediaItem {
    const newItem: MediaItem = {
      id: this.generateId(),
      name: name,
      createTime: Date.now(),
      folderId: folderId,
      uri: uri,
      size: size,
      privatePath: privatePath,
      originalFileName: originalFileName
    };
    this.items.push(newItem);
    this.saveData();
    return newItem;
  }

  deleteFolder(id: string): void {
    const foldersToDelete = new Set<string>();
    const collectSubFolders = (folderId: string): void => {
      foldersToDelete.add(folderId);
      const subFolders = this.getSubFolders(folderId);
      subFolders.forEach(sub => collectSubFolders(sub.id));
    };
    collectSubFolders(id);

    const itemIds = this.items
      .filter(item => foldersToDelete.has(item.folderId))
      .map(item => item.id);
    fileRepo.deletePrivateFiles(this.contentType, itemIds);

    this.items = this.items.filter(item => !foldersToDelete.has(item.folderId));
    this.folders = this.folders.filter(folder => !foldersToDelete.has(folder.id));
    this.saveData();
  }

  renameFolder(id: string, newName: string): void {
    const folder = this.folders.find(f => f.id === id);
    if (folder) {
      folder.name = newName;
      this.saveData();
    }
  }

  renameItem(id: string, newName: string): void {
    const item = this.items.find(i => i.id === id);
    if (item) {
      item.name = newName;
      this.saveData();
    }
  }

  moveItem(id: string, targetFolderId: string): void {
    const item = this.items.find(i => i.id === id);
    if (item) {
      item.folderId = targetFolderId;
      this.saveData();
    }
  }

  getItemById(id: string): MediaItem | undefined {
    return this.items.find(i => i.id === id);
  }

  // Recycle Bin (soft delete for items)
  softDeleteItem(id: string): void {
    const idx = this.items.findIndex(item => item.id === id);
    if (idx >= 0) {
      const item = this.items.splice(idx, 1)[0];
      item.deleteTime = Date.now();
      this.deletedItems.push(item);
      this.saveData();
    }
  }

  // Soft delete for folders: preserve structure, move to deletedFolders
  softDeleteFolder(id: string): void {
    const foldersToDelete = new Set<string>();
    const collectSubFolders = (folderId: string): void => {
      foldersToDelete.add(folderId);
      const allSubFolders = this.folders.filter(f => f.parentId === folderId && !f.deleteTime);
      allSubFolders.forEach(sub => collectSubFolders(sub.id));
    };
    collectSubFolders(id);

    const itemsInFolders = this.items.filter(item => foldersToDelete.has(item.folderId));
    const itemCount = itemsInFolders.length;

    const rootFolder = this.folders.find(f => f.id === id);
    if (rootFolder) {
      const deletedFolder: DeletedFolder = {
        folder: {
          id: rootFolder.id,
          name: rootFolder.name,
          parentId: rootFolder.parentId,
          createTime: rootFolder.createTime,
          deleteTime: Date.now(),
          originalParentId: rootFolder.parentId
        },
        itemCount: itemCount
      };
      this.deletedFolders.push(deletedFolder);
    }

    // Move items in folder and sub-folders to deletedItems
    itemsInFolders.forEach(item => {
      item.deleteTime = Date.now();
      this.deletedItems.push(item);
    });
    this.items = this.items.filter(item => !foldersToDelete.has(item.folderId));

    // Remove folders from active list
    this.folders = this.folders.filter(folder => !foldersToDelete.has(folder.id));
    this.saveData();
  }

  restoreItem(id: string): void {
    const idx = this.deletedItems.findIndex(item => item.id === id);
    if (idx >= 0) {
      const item = this.deletedItems.splice(idx, 1)[0];
      item.deleteTime = undefined;
      this.items.push(item);
      this.saveData();
    }
  }

  restoreFolder(id: string): void {
    const idx = this.deletedFolders.findIndex(df => df.folder.id === id);
    if (idx < 0) return;

    const deletedFolder = this.deletedFolders.splice(idx, 1)[0];
    const restoredFolder: Folder = {
      id: deletedFolder.folder.id,
      name: deletedFolder.folder.name,
      parentId: deletedFolder.folder.originalParentId ?? deletedFolder.folder.parentId,
      createTime: deletedFolder.folder.createTime,
      deleteTime: undefined
    };
    this.folders.push(restoredFolder);

    // Restore items that belonged to this folder
    const itemsToRestore = this.deletedItems.filter(item => item.folderId === id);
    itemsToRestore.forEach(item => {
      item.deleteTime = undefined;
      this.items.push(item);
    });
    this.deletedItems = this.deletedItems.filter(item => item.folderId !== id);
    this.saveData();
  }

  permanentlyDeleteItem(id: string): void {
    const idx = this.deletedItems.findIndex(item => item.id === id);
    if (idx >= 0) {
      fileRepo.deletePrivateFile(this.contentType, id);
      this.deletedItems.splice(idx, 1);
      this.saveData();
    }
  }

  permanentlyDeleteFolder(id: string): void {
    const idx = this.deletedFolders.findIndex(df => df.folder.id === id);
    if (idx < 0) return;
    this.deletedFolders.splice(idx, 1);

    const itemIds = this.deletedItems
      .filter(item => item.folderId === id)
      .map(item => item.id);
    fileRepo.deletePrivateFiles(this.contentType, itemIds);
    this.deletedItems = this.deletedItems.filter(item => item.folderId !== id);
    this.saveData();
  }

  clearRecycleBin(): void {
    const itemIds = this.deletedItems.map(item => item.id);
    fileRepo.deletePrivateFiles(this.contentType, itemIds);
    this.deletedItems = [];
    this.deletedFolders = [];
    this.saveData();
  }

  getDeletedItems(): MediaItem[] {
    return this.deletedItems;
  }

  getDeletedFolders(): DeletedFolder[] {
    return this.deletedFolders;
  }

  getAllFolders(): Folder[] {
    return this.folders;
  }

  isFolderNameDuplicate(name: string, parentId: string, excludeId?: string): boolean {
    return this.folders.some(f =>
      f.name === name && f.parentId === parentId && f.id !== excludeId && !f.deleteTime
    );
  }

  async loadData(): Promise<void> {
    if (!this.preferencesStore) {
      console.warn(`[MediaData:${this.contentType}] Preferences not initialized`);
      return;
    }
    try {
      const foldersJson = await this.preferencesStore.get('folders', '[]') as string;
      const itemsJson = await this.preferencesStore.get('items', '[]') as string;
      const deletedJson = await this.preferencesStore.get('deletedItems', '[]') as string;
      const deletedFoldersJson = await this.preferencesStore.get('deletedFolders', '[]') as string;
      this.folders = JSON.parse(foldersJson) as Folder[];
      this.items = JSON.parse(itemsJson) as MediaItem[];
      this.deletedItems = JSON.parse(deletedJson) as MediaItem[];
      this.deletedFolders = JSON.parse(deletedFoldersJson) as DeletedFolder[];
    } catch (err) {
      console.error(`[MediaData:${this.contentType}] Failed to load:`, JSON.stringify(err));
      this.folders = [];
      this.items = [];
      this.deletedItems = [];
      this.deletedFolders = [];
    }
  }

  async saveData(): Promise<void> {
    if (!this.preferencesStore) {
      console.warn(`[MediaData:${this.contentType}] Preferences not initialized`);
      return;
    }
    try {
      await this.preferencesStore.put('folders', JSON.stringify(this.folders));
      await this.preferencesStore.put('items', JSON.stringify(this.items));
      await this.preferencesStore.put('deletedItems', JSON.stringify(this.deletedItems));
      await this.preferencesStore.put('deletedFolders', JSON.stringify(this.deletedFolders));
      await this.preferencesStore.flush();
    } catch (err) {
      console.error(`[MediaData:${this.contentType}] Failed to save:`, JSON.stringify(err));
    }
  }

  // Backward compatibility aliases for PhotosPage / FolderDetailPage
  get photos(): MediaItem[] { return this.items; }
  getPhotosInFolder(folderId: string): MediaItem[] { return this.getItemsInFolder(folderId); }
  addPhoto(name: string, folderId: string): void { this.addItem(name, folderId); }
}

export const albumData = new MediaDataManager('photo', 'album_photo_data');
export const videoData = new MediaDataManager('video', 'album_video_data');
export const gifData = new MediaDataManager('gif', 'album_gif_data');
export const docData = new MediaDataManager('doc', 'album_doc_data');
export const recordData = new MediaDataManager('record', 'album_record_data');

export function getDataManager(type: string): MediaDataManager {
  switch (type) {
    case 'photo': return albumData;
    case 'video': return videoData;
    case 'gif': return gifData;
    case 'doc': return docData;
    case 'record': return recordData;
    default: return albumData;
  }
}
