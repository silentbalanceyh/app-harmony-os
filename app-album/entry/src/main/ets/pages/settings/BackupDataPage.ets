import router from '@ohos.router';
import fs from '@ohos.file.fs';
import common from '@ohos.app.ability.common';
import dataPreferences from '@ohos.data.preferences';
import util from '@ohos.util';
import { promptAction } from '@kit.ArkUI';
import { picker } from '@kit.CoreFileKit';
import { albumData, videoData, gifData, docData, recordData, Folder, MediaItem } from '../../models/AlbumData';
import { CryptoUtil } from '../../utils/CryptoUtil';
import { PasswordStore } from '../../utils/PasswordStore';

interface BackupEntry {
  folders: Folder[];
  items: MediaItem[];
  deletedItems: MediaItem[];
  deletedFoldersCount: number;
}

interface BackupMeta {
  backupTime: number;
  version: number;
  photo: BackupEntry;
  video: BackupEntry;
  gif: BackupEntry;
  doc: BackupEntry;
  record: BackupEntry;
}

@Preview
@Entry
@Component
struct BackupDataPage {
  @State lastBackup: string = '从未备份';
  @State lastBackupSize: string = '';
  @State isBackingUp: boolean = false;
  @State isRestoring: boolean = false;

  aboutToAppear(): void {
    void this.checkLastBackup();
  }

  private getAbilityContext(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private formatSize(bytes: number): string {
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  }

  private async checkLastBackup(): Promise<void> {
    try {
      const context = this.getAbilityContext();
      const filesDir = context.filesDir;
      const backupPath = filesDir + '/album_backup.enc';
      const exists = fs.accessSync(backupPath);
      if (exists) {
        const stat = fs.statSync(backupPath);
        const date = new Date(stat.mtime * 1000);
        this.lastBackup = `${date.getFullYear()}-${(date.getMonth() + 1).toString().padStart(2, '0')}-${date.getDate().toString().padStart(2, '0')} ${date.getHours().toString().padStart(2, '0')}:${date.getMinutes().toString().padStart(2, '0')}`;
        this.lastBackupSize = this.formatSize(stat.size);
      }
    } catch (err) {
      console.error('Check backup failed:', JSON.stringify(err));
    }
  }

  private async getBackupPassword(): Promise<string> {
    try {
      const prefs = await dataPreferences.getPreferences(this.getAbilityContext(), 'album_security');
      const hash = await prefs.get('password_hash', '') as string;
      return hash || 'default-backup-key';
    } catch {
      return 'default-backup-key';
    }
  }

  private async handleBackup(): Promise<void> {
    this.isBackingUp = true;
    try {
      const context = this.getAbilityContext();
      const filesDir = context.filesDir;
      const backupJsonPath = filesDir + '/album_backup_tmp.json';
      const backupEncPath = filesDir + '/album_backup.enc';

      const backupData: BackupMeta = {
        backupTime: Date.now(),
        version: 2,
        photo: {
          folders: albumData.folders,
          items: albumData.items,
          deletedItems: albumData.deletedItems,
          deletedFoldersCount: albumData.deletedFolders.length
        },
        video: {
          folders: videoData.folders,
          items: videoData.items,
          deletedItems: videoData.deletedItems,
          deletedFoldersCount: videoData.deletedFolders.length
        },
        gif: {
          folders: gifData.folders,
          items: gifData.items,
          deletedItems: gifData.deletedItems,
          deletedFoldersCount: gifData.deletedFolders.length
        },
        doc: {
          folders: docData.folders,
          items: docData.items,
          deletedItems: docData.deletedItems,
          deletedFoldersCount: docData.deletedFolders.length
        },
        record: {
          folders: recordData.folders,
          items: recordData.items,
          deletedItems: recordData.deletedItems,
          deletedFoldersCount: recordData.deletedFolders.length
        }
      };

      // Write JSON temp file
      const file = fs.openSync(backupJsonPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
      fs.writeSync(file.fd, JSON.stringify(backupData));
      fs.closeSync(file);

      // Encrypt
      const password = await this.getBackupPassword();
      const encrypted = await CryptoUtil.encryptFile(backupJsonPath, backupEncPath, password);

      // Clean up temp file
      try { fs.unlinkSync(backupJsonPath); } catch {}

      if (encrypted) {
        await this.checkLastBackup();
        promptAction.showToast({ message: '备份成功（已加密）', duration: 2000 });
      } else {
        promptAction.showToast({ message: '备份加密失败', duration: 2000 });
      }
    } catch (err) {
      console.error('Backup failed:', JSON.stringify(err));
      promptAction.showToast({ message: '备份失败', duration: 2000 });
    } finally {
      this.isBackingUp = false;
    }
  }

  private async handleRestore(): Promise<void> {
    this.isRestoring = true;
    try {
      const context = this.getAbilityContext();
      const filesDir = context.filesDir;
      const backupEncPath = filesDir + '/album_backup.enc';
      const backupJsonPath = filesDir + '/album_restore_tmp.json';

      if (!fs.accessSync(backupEncPath)) {
        promptAction.showToast({ message: '未找到备份文件', duration: 2000 });
        this.isRestoring = false;
        return;
      }

      AlertDialog.show({
        title: '恢复数据',
        message: '恢复将覆盖当前所有数据，确定继续吗？',
        autoCancel: true,
        alignment: DialogAlignment.Center,
        gridCount: 4,
        primaryButton: { value: '取消', action: () => { this.isRestoring = false; } },
        secondaryButton: {
          value: '恢复',
          fontColor: '#6366F1',
          action: () => { void this.doRestore(backupEncPath, backupJsonPath); }
        }
      });
    } catch (err) {
      console.error('Restore check failed:', JSON.stringify(err));
      this.isRestoring = false;
    }
  }

  private async doRestore(encPath: string, jsonPath: string): Promise<void> {
    try {
      const password = await this.getBackupPassword();
      const decrypted = await CryptoUtil.decryptFile(encPath, jsonPath, password);
      if (!decrypted) {
        promptAction.showToast({ message: '解密失败，密码可能已变更', duration: 2000 });
        this.isRestoring = false;
        return;
      }

      const readFile = fs.openSync(jsonPath, fs.OpenMode.READ_ONLY);
      const stat = fs.statSync(jsonPath);
      const readBuf = new ArrayBuffer(stat.size);
      fs.readSync(readFile.fd, readBuf);
      fs.closeSync(readFile);
      const decoder = util.TextDecoder.create('utf-8');
      const content = decoder.decodeToString(new Uint8Array(readBuf));
      const data = JSON.parse(content) as BackupMeta;

      // Restore each manager
      const managers = [albumData, videoData, gifData, docData, recordData];
      const entries: BackupEntry[] = [data.photo, data.video, data.gif, data.doc, data.record];

      managers.forEach((mgr, idx) => {
        mgr.folders = entries[idx].folders;
        mgr.items = entries[idx].items;
        mgr.deletedItems = entries[idx].deletedItems;
        mgr.deletedFolders = [];
        mgr.saveData();
      });

      // Clean up
      try { fs.unlinkSync(jsonPath); } catch {}

      promptAction.showToast({ message: '恢复成功', duration: 2000 });
    } catch (err) {
      console.error('Restore failed:', JSON.stringify(err));
      promptAction.showToast({ message: '恢复失败', duration: 2000 });
    } finally {
      this.isRestoring = false;
    }
  }

  build() {
    Column({ space: 12 }) {
      Row({ space: 12 }) {
        Button('←')
          .width(36).height(36).fontSize(18).fontColor('#111827')
          .backgroundColor('#FFFFFF').borderRadius(18)
          .onClick(() => { router.back(); })
        Text('备份数据')
          .fontSize(20).fontWeight(FontWeight.Bold).fontColor('#111827')
        Blank()
      }
      .width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 })

      Column({ space: 16 }) {
        Text('💾').fontSize(48)
        Text(`上次备份: ${this.lastBackup}`).fontSize(16).fontColor('#6B7280')
        if (this.lastBackupSize) {
          Text(`备份大小: ${this.lastBackupSize}`).fontSize(14).fontColor('#9CA3AF')
        }
        Text('备份数据已加密，包含目录结构和元数据').fontSize(13).fontColor('#9CA3AF')

        Column({ space: 8 }) {
          Button(this.isBackingUp ? '备份中...' : '立即备份')
            .width('80%').height(44).fontSize(16).fontColor('#FFFFFF')
            .backgroundColor(this.isBackingUp ? '#9CA3AF' : '#6366F1')
            .borderRadius(8)
            .enabled(!this.isBackingUp && !this.isRestoring)
            .onClick(() => { void this.handleBackup(); })

          Button(this.isRestoring ? '恢复中...' : '从备份恢复')
            .width('80%').height(44).fontSize(16).fontColor('#6366F1')
            .backgroundColor('#F3F4F6')
            .borderRadius(8)
            .enabled(!this.isBackingUp && !this.isRestoring)
            .onClick(() => { void this.handleRestore(); })
        }
        .margin({ top: 8 })
      }
      .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
    }
    .width('100%').height('100%').backgroundColor('#F3F6FC')
  }
}
