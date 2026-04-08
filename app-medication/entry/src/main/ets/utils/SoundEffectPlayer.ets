import common from '@ohos.app.ability.common';
import media from '@ohos.multimedia.media';
import audio from '@ohos.multimedia.audio';
import resourceManager from '@ohos.resourceManager';

const MAX_STREAMS: number = 2;

const AUDIO_RENDERER_INFO: audio.AudioRendererInfo = {
  usage: audio.StreamUsage.STREAM_USAGE_NOTIFICATION,
  rendererFlags: 0
};

const PLAY_PARAMETERS: media.PlayParameters = {
  loop: 0,
  leftVolume: 1.0,
  rightVolume: 1.0,
  priority: 1
};

export default class SoundEffectPlayer {
  private soundPool?: media.SoundPool;
  private readonly soundIds: Map<string, number> = new Map<string, number>();
  private readonly loadingSounds: Map<string, Promise<number>> = new Map<string, Promise<number>>();

  async play(context: common.UIAbilityContext, rawFilePath: string): Promise<void> {
    try {
      const soundPool: media.SoundPool = await this.getSoundPool();
      const soundId: number = await this.getSoundId(context, rawFilePath);

      // 返回 Promise，等待播放完成
      return new Promise<void>((resolve, reject) => {
        let streamId: number = 0;

        // 监听播放完成事件
        soundPool.on('playFinished', () => {
          console.info('[SoundEffectPlayer] Play finished: ' + rawFilePath);
          resolve();
        });

        // 开始播放
        soundPool.play(soundId, PLAY_PARAMETERS).then((id: number) => {
          streamId = id;
          console.info('[SoundEffectPlayer] Playing: ' + rawFilePath + ', streamId=' + id);
        }).catch((err: Error) => {
          console.error('[SoundEffectPlayer] Play failed: ' + JSON.stringify(err));
          reject(err);
        });
      });
    } catch (err) {
      console.error('Sound effect play failed: ' + JSON.stringify(err));
    }
  }

  private async getSoundPool(): Promise<media.SoundPool> {
    if (!this.soundPool) {
      this.soundPool = await media.createSoundPool(MAX_STREAMS, AUDIO_RENDERER_INFO);
    }
    return this.soundPool;
  }

  private async getSoundId(context: common.UIAbilityContext, rawFilePath: string): Promise<number> {
    const cachedSoundId: number | undefined = this.soundIds.get(rawFilePath);
    if (cachedSoundId !== undefined) {
      return cachedSoundId;
    }

    const loadingSound: Promise<number> | undefined = this.loadingSounds.get(rawFilePath);
    if (loadingSound) {
      return loadingSound;
    }

    const soundPromise: Promise<number> = this.loadSound(context, rawFilePath);
    this.loadingSounds.set(rawFilePath, soundPromise);
    try {
      const soundId: number = await soundPromise;
      this.soundIds.set(rawFilePath, soundId);
      return soundId;
    } finally {
      this.loadingSounds.delete(rawFilePath);
    }
  }

  private async loadSound(context: common.UIAbilityContext, rawFilePath: string): Promise<number> {
    const rawFileDescriptor: resourceManager.RawFileDescriptor = await context.resourceManager.getRawFd(rawFilePath);
    try {
      const soundPool: media.SoundPool = await this.getSoundPool();
      return await soundPool.load(rawFileDescriptor.fd, rawFileDescriptor.offset, rawFileDescriptor.length);
    } finally {
      await context.resourceManager.closeRawFd(rawFilePath);
    }
  }
}
