import common from '@ohos.app.ability.common';
import fs from '@ohos.file.fs';
import font from '@ohos.font';

let albumFontRegistered: boolean = false;
const FONT_FAMILY: string = 'AlbumHannotateTC';
const RAW_FILE_PATH: string = 'fonts/HannotateTC-Regular.ttf';
const RAW_FILE_RESOURCE: ResourceStr = $rawfile('fonts/HannotateTC-Regular.ttf');

function registerFromResource(): void {
  console.info('Album font step: registerFont by rawfile start');
  font.registerFont({
    familyName: FONT_FAMILY,
    familySrc: RAW_FILE_RESOURCE
  });
  console.info('Album font step: registerFont by rawfile ok');
}

async function registerFromSandboxFile(context: common.UIAbilityContext): Promise<void> {
  console.info('Album font step: getRawFileContent start');
  const fontBytes: Uint8Array = await context.resourceManager.getRawFileContent(RAW_FILE_PATH);
  console.info(`Album font step: getRawFileContent ok size=${fontBytes.byteLength}`);
  const fontDir: string = `${context.filesDir}/fonts`;
  const fontPath: string = `${fontDir}/HannotateTC-Regular.ttf`;
  try {
    fs.accessSync(fontDir);
    console.info(`Album font step: fontDir exists ${fontDir}`);
  } catch (_err) {
    fs.mkdirSync(fontDir, true);
    console.info(`Album font step: fontDir created ${fontDir}`);
  }

  const file = fs.openSync(fontPath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.READ_WRITE);
  console.info(`Album font step: writeSync start -> ${fontPath}`);
  fs.writeSync(file.fd, fontBytes.buffer);
  fs.closeSync(file);
  console.info('Album font step: writeSync ok');
  console.info(`Album font step: registerFont by sandbox start src=${fontPath}`);
  font.registerFont({
    familyName: FONT_FAMILY,
    familySrc: fontPath
  });
  console.info('Album font step: registerFont by sandbox ok');
}

export async function ensureAlbumFontRegistered(context: common.UIAbilityContext): Promise<void> {
  if (albumFontRegistered) {
    console.info('Album font already registered');
    return;
  }

  try {
    try {
      registerFromResource();
    } catch (resourceErr) {
      console.error('Album font rawfile register failed: ' + JSON.stringify(resourceErr));
      await registerFromSandboxFile(context);
    }
    albumFontRegistered = true;
  } catch (err) {
    console.error('Failed to register album font: ' + JSON.stringify(err));
  }
}
