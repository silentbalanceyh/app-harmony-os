import router from '@ohos.router';
import common from '@ohos.app.ability.common';
import { promptAction } from '@kit.ArkUI';
import { settingsStore } from '../../utils/SettingsStore';
import { userAuth } from '@kit.UserAuthenticationKit';

@Preview
@Entry
@Component
struct FaceIdPage {
  @State faceIdEnabled: boolean = false;
  @State folderAccess: boolean = false;
  @State authStatus: string = '';

  aboutToAppear(): void {
    void this.loadSettings();
  }

  private getAbilityContext(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private async loadSettings(): Promise<void> {
    await settingsStore.init(this.getAbilityContext());
    this.faceIdEnabled = await settingsStore.getFaceIdEnabled();
    this.folderAccess = await settingsStore.getFolderFaceIdAccess();
  }

  private async checkFaceIdSupport(): Promise<boolean> {
    try {
      const auth = userAuth.getUserAuthInstance({
        challenge: new Uint8Array([0]),
        authType: [userAuth.UserAuthType.FACE],
        authTrustLevel: userAuth.AuthTrustLevel.ATL3
      }, { title: '验证 Face ID' });
      return true;
    } catch (err) {
      console.error('Face ID check failed:', JSON.stringify(err));
      return false;
    }
  }

  private async performFaceAuth(): Promise<boolean> {
    try {
      const authInstance = userAuth.getUserAuthInstance({
        challenge: new Uint8Array([1, 2, 3, 4]),
        authType: [userAuth.UserAuthType.FACE],
        authTrustLevel: userAuth.AuthTrustLevel.ATL3
      }, { title: '验证 Face ID 以开启' });

      return new Promise<boolean>((resolve) => {
        authInstance.on('result', {
          onResult(result: userAuth.UserAuthResult) {
            if (result.result === 0) {
              resolve(true);
            } else {
              resolve(false);
            }
            authInstance.off('result');
          }
        });
        authInstance.start();
      });
    } catch (err) {
      console.error('Face ID auth failed:', JSON.stringify(err));
      return false;
    }
  }

  private async toggleFaceId(isOn: boolean): Promise<void> {
    if (isOn) {
      const supported = await this.checkFaceIdSupport();
      if (!supported) {
        promptAction.showToast({
          message: '当前设备不支持 Face ID',
          duration: 2000
        });
        return;
      }
      this.authStatus = '正在验证 Face ID...';
      const authenticated = await this.performFaceAuth();
      this.authStatus = '';
      if (!authenticated) {
        promptAction.showToast({
          message: 'Face ID 验证失败，未开启',
          duration: 2000
        });
        return;
      }
    }
    await settingsStore.setFaceIdEnabled(isOn);
    this.faceIdEnabled = isOn;
    promptAction.showToast({
      message: isOn ? 'Face ID 解锁已开启' : 'Face ID 解锁已关闭',
      duration: 2000
    });
  }

  private async toggleFolderAccess(isOn: boolean): Promise<void> {
    if (isOn && !this.faceIdEnabled) {
      promptAction.showToast({
        message: '请先开启 Face ID 解锁',
        duration: 2000
      });
      return;
    }
    await settingsStore.setFolderFaceIdAccess(isOn);
    this.folderAccess = isOn;
    promptAction.showToast({
      message: isOn ? '文件夹 Face ID 访问已开启' : '文件夹 Face ID 访问已关闭',
      duration: 2000
    });
  }

  build() {
    Column({ space: 12 }) {
      Row({ space: 12 }) {
        Button('←')
          .width(36).height(36).fontSize(18).fontColor('#111827')
          .backgroundColor('#FFFFFF').borderRadius(18)
          .onClick(() => { router.back(); })
        Text('Face ID')
          .fontSize(20).fontWeight(FontWeight.Bold).fontColor('#111827')
        Blank()
      }
      .width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 })

      if (this.authStatus) {
        Row() {
          LoadingProgress().width(20).height(20).color('#6366F1')
          Text(this.authStatus).fontSize(14).fontColor('#6366F1').margin({ left: 8 })
        }
        .width('100%').padding({ left: 16, right: 16 })
      }

      Column({ space: 0 }) {
        Row() {
          Column() {
            Text('Face ID 解锁').fontSize(16).fontColor('#111827')
            Text('使用面部识别解锁加密相册').fontSize(13).fontColor('#6B7280')
          }
          Blank()
          Toggle({ type: ToggleType.Switch, isOn: this.faceIdEnabled })
            .onChange((isOn: boolean) => { void this.toggleFaceId(isOn); })
        }
        .width('100%').padding(16)

        Divider().color('#E5E7EB')

        Row() {
          Column() {
            Text('文件夹 Face ID 访问').fontSize(16).fontColor('#111827')
            Text('使用 Face ID 访问特定文件夹').fontSize(13).fontColor('#6B7280')
          }
          Blank()
          Toggle({ type: ToggleType.Switch, isOn: this.folderAccess })
            .onChange((isOn: boolean) => { void this.toggleFolderAccess(isOn); })
        }
        .width('100%').padding(16)
      }
      .backgroundColor('#FFFFFF').borderRadius(8).margin({ left: 16, right: 16 })

      Blank()
    }
    .width('100%').height('100%').backgroundColor('#F3F6FC')
  }
}
