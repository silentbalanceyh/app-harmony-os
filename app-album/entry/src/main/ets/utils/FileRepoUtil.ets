import fs from '@ohos.file.fs';
import common from '@ohos.app.ability.common';

const REPO_DIR = 'album_repo';

export class FileRepoUtil {
  private context: common.UIAbilityContext | null = null;

  init(context: common.UIAbilityContext): void {
    this.context = context;
    this.ensureRepoDir();
  }

  private ensureRepoDir(): void {
    if (!this.context) return;
    const repoPath = this.context.filesDir + '/' + REPO_DIR;
    try {
      if (!fs.accessSync(repoPath)) {
        fs.mkdirSync(repoPath);
      }
    } catch (err) {
      console.error('[FileRepo] Failed to create repo dir:', JSON.stringify(err));
    }
  }

  private getRepoPath(): string {
    if (!this.context) return '';
    return this.context.filesDir + '/' + REPO_DIR;
  }

  async copyToRepo(sourceUri: string, contentType: string, itemId: string): Promise<string> {
    const repoPath = this.getRepoPath();
    if (!repoPath) return '';

    const typeDir = repoPath + '/' + contentType;
    try {
      if (!fs.accessSync(typeDir)) {
        fs.mkdirSync(typeDir);
      }
    } catch {
      // dir may already exist
    }

    const destPath = typeDir + '/' + itemId;
    try {
      const srcFile = fs.openSync(sourceUri, fs.OpenMode.READ_ONLY);
      const destFile = fs.openSync(destPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
      const bufferSize = 4096;
      let buffer = new ArrayBuffer(bufferSize);
      let readLen = fs.readSync(srcFile.fd, buffer);
      while (readLen > 0) {
        fs.writeSync(destFile.fd, buffer, { length: readLen });
        readLen = fs.readSync(srcFile.fd, buffer);
      }
      fs.closeSync(srcFile);
      fs.closeSync(destFile);
      return destPath;
    } catch (err) {
      console.error('[FileRepo] Copy failed:', JSON.stringify(err));
      return '';
    }
  }

  getFilePrivatePath(contentType: string, itemId: string): string {
    return this.getRepoPath() + '/' + contentType + '/' + itemId;
  }

  async deletePrivateFile(contentType: string, itemId: string): Promise<void> {
    const filePath = this.getFilePrivatePath(contentType, itemId);
    try {
      if (fs.accessSync(filePath)) {
        fs.unlinkSync(filePath);
      }
    } catch (err) {
      console.error('[FileRepo] Delete failed:', JSON.stringify(err));
    }
  }

  async deletePrivateFiles(contentType: string, itemIds: string[]): Promise<void> {
    for (const id of itemIds) {
      await this.deletePrivateFile(contentType, id);
    }
  }

  async getPrivateFileSize(contentType: string, itemId: string): Promise<number> {
    const filePath = this.getFilePrivatePath(contentType, itemId);
    try {
      if (fs.accessSync(filePath)) {
        const stat = fs.statSync(filePath);
        return stat.size;
      }
    } catch {
      // file not found
    }
    return 0;
  }

  async getRepoTotalSize(): Promise<number> {
    const repoPath = this.getRepoPath();
    let totalSize = 0;
    try {
      this.calcDirSize(repoPath, (size: number) => { totalSize += size; });
    } catch {
      // ignore
    }
    return totalSize;
  }

  private calcDirSize(dirPath: string, onSize: (size: number) => void): void {
    try {
      const list = fs.listFileSync(dirPath);
      for (const name of list) {
        const fullPath = dirPath + '/' + name;
        try {
          const stat = fs.statSync(fullPath);
          if (stat.isDirectory()) {
            this.calcDirSize(fullPath, onSize);
          } else {
            onSize(stat.size);
          }
        } catch {
          // skip inaccessible
        }
      }
    } catch {
      // skip inaccessible dir
    }
  }

  async clearRepo(): Promise<void> {
    const repoPath = this.getRepoPath();
    try {
      this.removeDirContents(repoPath);
    } catch (err) {
      console.error('[FileRepo] Clear failed:', JSON.stringify(err));
    }
  }

  private removeDirContents(dirPath: string): void {
    try {
      const list = fs.listFileSync(dirPath);
      for (const name of list) {
        const fullPath = dirPath + '/' + name;
        try {
          const stat = fs.statSync(fullPath);
          if (stat.isDirectory()) {
            this.removeDirContents(fullPath);
            fs.rmdirSync(fullPath);
          } else {
            fs.unlinkSync(fullPath);
          }
        } catch {
          // skip
        }
      }
    } catch {
      // skip
    }
  }
}

export const fileRepo = new FileRepoUtil();
