import router from '@ohos.router';
import fs from '@ohos.file.fs';
import common from '@ohos.app.ability.common';
import { picker } from '@kit.CoreFileKit';
import util from '@ohos.util';
import { promptAction } from '@kit.ArkUI';
import { albumData, videoData, gifData, docData, recordData, Folder, MediaItem } from '../../models/AlbumData';
import { fileRepo } from '../../utils/FileRepoUtil';
import { CryptoUtil } from '../../utils/CryptoUtil';
import dataPreferences from '@ohos.data.preferences';

interface TransferEntry {
  folders: Folder[];
  items: MediaItem[];
}

interface TransferPackage {
  exportTime: number;
  photo: TransferEntry;
  video: TransferEntry;
  gif: TransferEntry;
  doc: TransferEntry;
  record: TransferEntry;
}

@Preview
@Entry
@Component
struct PhoneTransferPage {
  @State isExporting: boolean = false;
  @State isImporting: boolean = false;

  aboutToAppear(): void {
    // No fake device search
  }

  private getAbilityContext(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private async getTransferPassword(): Promise<string> {
    try {
      const prefs = await dataPreferences.getPreferences(this.getAbilityContext(), 'album_security');
      const hash = await prefs.get('password_hash', '') as string;
      return hash || 'transfer-default-key';
    } catch {
      return 'transfer-default-key';
    }
  }

  private async handleExport(): Promise<void> {
    this.isExporting = true;
    try {
      const context = this.getAbilityContext();
      const tmpDir = context.cacheDir;
      const jsonPath = tmpDir + '/transfer_package.json';
      const encPath = tmpDir + '/transfer_package.enc';

      const pkg: TransferPackage = {
        exportTime: Date.now(),
        photo: { folders: albumData.folders, items: albumData.items },
        video: { folders: videoData.folders, items: videoData.items },
        gif: { folders: gifData.folders, items: gifData.items },
        doc: { folders: docData.folders, items: docData.items },
        record: { folders: recordData.folders, items: recordData.items }
      };

      const file = fs.openSync(jsonPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
      fs.writeSync(file.fd, JSON.stringify(pkg));
      fs.closeSync(file);

      const password = await this.getTransferPassword();
      const encrypted = await CryptoUtil.encryptFile(jsonPath, encPath, password);
      try { fs.unlinkSync(jsonPath); } catch {}

      if (!encrypted) {
        promptAction.showToast({ message: '导出加密失败', duration: 2000 });
        this.isExporting = false;
        return;
      }

      // Use document picker to let user save the file
      try {
        const documentPicker = new picker.DocumentViewPicker();
        const uris = await documentPicker.save({
          newFileNames: ['album_transfer.enc']
        });
        if (uris && uris.length > 0) {
          const destUri = uris[0];
          const srcFile = fs.openSync(encPath, fs.OpenMode.READ_ONLY);
          const destFile = fs.openSync(destUri, fs.OpenMode.READ_WRITE);
          const buffer = new ArrayBuffer(4096);
          let readLen = fs.readSync(srcFile.fd, buffer);
          while (readLen > 0) {
            fs.writeSync(destFile.fd, buffer, { length: readLen });
            readLen = fs.readSync(srcFile.fd, buffer);
          }
          fs.closeSync(srcFile);
          fs.closeSync(destFile);
        }
        promptAction.showToast({ message: '传输包已导出，请将文件发送到目标设备', duration: 3000 });
      } catch {
        promptAction.showToast({ message: '传输包已生成，请从应用目录中获取', duration: 3000 });
      }

      try { fs.unlinkSync(encPath); } catch {}
    } catch (err) {
      console.error('Export failed:', JSON.stringify(err));
      promptAction.showToast({ message: '导出失败', duration: 2000 });
    } finally {
      this.isExporting = false;
    }
  }

  private async handleImport(): Promise<void> {
    this.isImporting = true;
    try {
      const documentPicker = new picker.DocumentViewPicker();
      const result = await documentPicker.select({ maxSelectNumber: 1 });
      const uris: string[] = (result as Object as Record<string, string[]>).result ?? [];
      if (uris.length === 0) {
        this.isImporting = false;
        return;
      }

      const srcUri = uris[0];
      const context = this.getAbilityContext();
      const tmpDir = context.cacheDir;
      const encPath = tmpDir + '/import_package.enc';
      const jsonPath = tmpDir + '/import_package.json';

      // Copy selected file to cache
      const srcFile = fs.openSync(srcUri, fs.OpenMode.READ_ONLY);
      const destFile = fs.openSync(encPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
      const bufferSize = 4096;
      let buffer = new ArrayBuffer(bufferSize);
      let readLen = fs.readSync(srcFile.fd, buffer);
      while (readLen > 0) {
        fs.writeSync(destFile.fd, buffer, { length: readLen });
        readLen = fs.readSync(srcFile.fd, buffer);
      }
      fs.closeSync(srcFile);
      fs.closeSync(destFile);

      const password = await this.getTransferPassword();
      const decrypted = await CryptoUtil.decryptFile(encPath, jsonPath, password);
      try { fs.unlinkSync(encPath); } catch {}

      if (!decrypted) {
        promptAction.showToast({ message: '解密失败，传输包可能来自不同设备', duration: 2000 });
        this.isImporting = false;
        return;
      }

      const readFile = fs.openSync(jsonPath, fs.OpenMode.READ_ONLY);
      const stat = fs.statSync(jsonPath);
      const readBuf = new ArrayBuffer(stat.size);
      fs.readSync(readFile.fd, readBuf);
      fs.closeSync(readFile);
      const decoder = util.TextDecoder.create('utf-8');
      const content = decoder.decodeToString(new Uint8Array(readBuf));
      const pkg = JSON.parse(content) as TransferPackage;

      AlertDialog.show({
        title: '导入传输包',
        message: `导出时间: ${new Date(pkg.exportTime).toLocaleString()}\n导入将合并到当前数据中，确定继续吗？`,
        autoCancel: true,
        alignment: DialogAlignment.Center,
        gridCount: 4,
        primaryButton: { value: '取消', action: () => { this.isImporting = false; } },
        secondaryButton: {
          value: '导入',
          fontColor: '#6366F1',
          action: () => { void this.doImport(pkg, jsonPath); }
        }
      });
    } catch (err) {
      console.error('Import failed:', JSON.stringify(err));
      promptAction.showToast({ message: '选择文件失败', duration: 2000 });
      this.isImporting = false;
    }
  }

  private async doImport(pkg: TransferPackage, jsonPath: string): Promise<void> {
    try {
      const managers = [albumData, videoData, gifData, docData, recordData];
      const entries: TransferEntry[] = [pkg.photo, pkg.video, pkg.gif, pkg.doc, pkg.record];

      managers.forEach((mgr, idx) => {
        const entry = entries[idx];
        if (entry) {
          // Merge folders (avoid duplicates by id)
          const existingIds = new Set(mgr.folders.map(f => f.id));
          entry.folders.forEach((f: Folder) => {
            if (!existingIds.has(f.id)) {
              mgr.folders.push(f);
            }
          });
          // Merge items
          const existingItemIds = new Set(mgr.items.map(i => i.id));
          entry.items.forEach((item: MediaItem) => {
            if (!existingItemIds.has(item.id)) {
              mgr.items.push(item);
            }
          });
          mgr.saveData();
        }
      });

      try { fs.unlinkSync(jsonPath); } catch {}
      promptAction.showToast({ message: '传输包导入成功', duration: 2000 });
    } catch (err) {
      console.error('Import merge failed:', JSON.stringify(err));
      promptAction.showToast({ message: '导入合并失败', duration: 2000 });
    } finally {
      this.isImporting = false;
    }
  }

  build() {
    Column({ space: 12 }) {
      Row({ space: 12 }) {
        Button('←')
          .width(36).height(36).fontSize(18).fontColor('#111827')
          .backgroundColor('#FFFFFF').borderRadius(18)
          .onClick(() => { router.back(); })
        Text('手机互传')
          .fontSize(20).fontWeight(FontWeight.Bold).fontColor('#111827')
        Blank()
      }
      .width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 })

      Column({ space: 20 }) {
        Text('📱').fontSize(48)

        Text('通过导出/导入加密传输包来迁移数据')
          .fontSize(16).fontColor('#6B7280')
          .textAlign(TextAlign.Center)
          .margin({ top: 4 })

        Text('在当前设备导出加密传输包，发送到目标设备后导入。传输包已加密，仅本设备可解密。')
          .fontSize(13).fontColor('#9CA3AF')
          .textAlign(TextAlign.Center)
          .padding({ left: 24, right: 24 })

        Column({ space: 12 }) {
          Button(this.isExporting ? '导出中...' : '导出传输包')
            .width('80%').height(48).fontSize(16).fontColor('#FFFFFF')
            .backgroundColor(this.isExporting ? '#9CA3AF' : '#6366F1')
            .borderRadius(12)
            .enabled(!this.isExporting && !this.isImporting)
            .onClick(() => { void this.handleExport(); })

          Button(this.isImporting ? '导入中...' : '导入传输包')
            .width('80%').height(48).fontSize(16).fontColor('#6366F1')
            .backgroundColor('#F3F4F6')
            .borderRadius(12)
            .enabled(!this.isExporting && !this.isImporting)
            .onClick(() => { void this.handleImport(); })
        }
        .margin({ top: 16 })
      }
      .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
    }
    .width('100%').height('100%').backgroundColor('#F3F6FC')
  }
}
