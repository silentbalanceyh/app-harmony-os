import cryptoFramework from '@ohos.security.cryptoFramework';
import util from '@ohos.util';
import fs from '@ohos.file.fs';

const SALT_LENGTH = 16;
const KEY_LENGTH = 256;
const IV_LENGTH = 16;

function uint8ArrayToHex(arr: Uint8Array): string {
  return Array.from(arr).map(b => b.toString(16).padStart(2, '0')).join('');
}

function hexToUint8Array(hex: string): Uint8Array {
  const arr = new Uint8Array(hex.length / 2);
  for (let i = 0; i < hex.length; i += 2) {
    arr[i / 2] = parseInt(hex.substring(i, i + 2), 16);
  }
  return arr;
}

function stringToUint8Array(str: string): Uint8Array {
  const textEncoder = new util.TextEncoder();
  return textEncoder.encodeInto(str);
}

function uint8ArrayToString(arr: Uint8Array): string {
  const textDecoder = util.TextDecoder.create('utf-8');
  return textDecoder.decodeToString(arr);
}

function createIvParamsSpec(iv: Uint8Array): cryptoFramework.IvParamsSpec {
  const spec: cryptoFramework.IvParamsSpec = {
    algName: 'IvParamsSpec',
    iv: { data: iv }
  };
  return spec;
}

export class CryptoUtil {
  static generateSalt(): Uint8Array {
    const salt = new Uint8Array(SALT_LENGTH);
    for (let i = 0; i < SALT_LENGTH; i++) {
      salt[i] = Math.floor(Math.random() * 256);
    }
    return salt;
  }

  static async hashPassword(password: string, salt: Uint8Array): Promise<string> {
    const md = cryptoFramework.createMd('SHA256');
    const pwdBytes = stringToUint8Array(password);
    const salted = new Uint8Array(pwdBytes.length + salt.length);
    salted.set(pwdBytes, 0);
    salted.set(salt, pwdBytes.length);
    await md.update({ data: salted });
    const result = await md.digest();
    return uint8ArrayToHex(salt) + ':' + uint8ArrayToHex(result.data);
  }

  static async verifyPassword(password: string, storedHash: string): Promise<boolean> {
    const parts = storedHash.split(':');
    if (parts.length !== 2) return false;
    const salt = hexToUint8Array(parts[0]);
    const computed = await CryptoUtil.hashPassword(password, salt);
    return computed === storedHash;
  }

  static isLegacyHash(hash: string): boolean {
    return !hash.includes(':');
  }

  static async migrateLegacyHash(password: string, legacyHash: string): Promise<string> {
    if (simpleHash(password) !== legacyHash) {
      return legacyHash;
    }
    const salt = CryptoUtil.generateSalt();
    return await CryptoUtil.hashPassword(password, salt);
  }

  static async deriveKey(password: string, salt: Uint8Array): Promise<cryptoFramework.SymKey | null> {
    try {
      const symKeyGenerator = cryptoFramework.createSymKeyGenerator('AES256');
      const md = cryptoFramework.createMd('SHA256');
      const pwdBytes = stringToUint8Array(password);
      const material = new Uint8Array(pwdBytes.length + salt.length);
      material.set(pwdBytes, 0);
      material.set(salt, pwdBytes.length);
      await md.update({ data: material });
      const digest = await md.digest();
      const keyBlob: cryptoFramework.DataBlob = { data: digest.data };
      const symKey = await symKeyGenerator.convertKey(keyBlob);
      return symKey;
    } catch (err) {
      console.error('[Crypto] Key derivation failed:', JSON.stringify(err));
      return null;
    }
  }

  static async encryptFile(srcPath: string, destPath: string, password: string): Promise<boolean> {
    try {
      const salt = CryptoUtil.generateSalt();
      const cipher = cryptoFramework.createCipher('AES256|CBC|PKCS7');
      const symKeyGenerator = cryptoFramework.createSymKeyGenerator('AES256');
      const md = cryptoFramework.createMd('SHA256');
      const pwdBytes = stringToUint8Array(password);
      const material = new Uint8Array(pwdBytes.length + salt.length);
      material.set(pwdBytes, 0);
      material.set(salt, pwdBytes.length);
      await md.update({ data: material });
      const digest = await md.digest();
      const symKey = await symKeyGenerator.convertKey({ data: digest.data });

      const iv = new Uint8Array(IV_LENGTH);
      for (let i = 0; i < IV_LENGTH; i++) {
        iv[i] = Math.floor(Math.random() * 256);
      }
      const params = createIvParamsSpec(iv);

      await cipher.init(cryptoFramework.CryptoMode.ENCRYPT_MODE, symKey, params);

      const srcFile = fs.openSync(srcPath, fs.OpenMode.READ_ONLY);
      const destFile = fs.openSync(destPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);

      const saltData: cryptoFramework.DataBlob = { data: salt };
      const ivData: cryptoFramework.DataBlob = { data: iv };
      fs.writeSync(destFile.fd, saltData.data.buffer);
      fs.writeSync(destFile.fd, ivData.data.buffer);

      const bufferSize = 4096;
      let buffer = new ArrayBuffer(bufferSize);
      let readLen = fs.readSync(srcFile.fd, buffer);
      while (readLen > 0) {
        const chunk = new Uint8Array(buffer, 0, readLen);
        const encrypted = await cipher.update({ data: chunk });
        if (encrypted.data) {
          fs.writeSync(destFile.fd, encrypted.data.buffer);
        }
        readLen = fs.readSync(srcFile.fd, buffer);
      }
      const finalResult = await cipher.doFinal({ data: new Uint8Array(0) });
      if (finalResult.data) {
        fs.writeSync(destFile.fd, finalResult.data.buffer);
      }

      fs.closeSync(srcFile);
      fs.closeSync(destFile);
      return true;
    } catch (err) {
      console.error('[Crypto] Encrypt failed:', JSON.stringify(err));
      return false;
    }
  }

  static async decryptFile(srcPath: string, destPath: string, password: string): Promise<boolean> {
    try {
      const srcFile = fs.openSync(srcPath, fs.OpenMode.READ_ONLY);

      const saltBuf = new ArrayBuffer(SALT_LENGTH);
      fs.readSync(srcFile.fd, saltBuf);
      const salt = new Uint8Array(saltBuf);

      const ivBuf = new ArrayBuffer(IV_LENGTH);
      fs.readSync(srcFile.fd, ivBuf);
      const iv = new Uint8Array(ivBuf);

      const symKeyGenerator = cryptoFramework.createSymKeyGenerator('AES256');
      const md = cryptoFramework.createMd('SHA256');
      const pwdBytes = stringToUint8Array(password);
      const material = new Uint8Array(pwdBytes.length + salt.length);
      material.set(pwdBytes, 0);
      material.set(salt, pwdBytes.length);
      await md.update({ data: material });
      const digest = await md.digest();
      const symKey = await symKeyGenerator.convertKey({ data: digest.data });

      const cipher = cryptoFramework.createCipher('AES256|CBC|PKCS7');
      const params = createIvParamsSpec(iv);
      await cipher.init(cryptoFramework.CryptoMode.DECRYPT_MODE, symKey, params);

      const destFile = fs.openSync(destPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
      const bufferSize = 4096;
      let buffer = new ArrayBuffer(bufferSize);
      let readLen = fs.readSync(srcFile.fd, buffer);
      while (readLen > 0) {
        const chunk = new Uint8Array(buffer, 0, readLen);
        const decrypted = await cipher.update({ data: chunk });
        if (decrypted.data) {
          fs.writeSync(destFile.fd, decrypted.data.buffer);
        }
        readLen = fs.readSync(srcFile.fd, buffer);
      }
      const finalResult = await cipher.doFinal({ data: new Uint8Array(0) });
      if (finalResult.data) {
        fs.writeSync(destFile.fd, finalResult.data.buffer);
      }

      fs.closeSync(srcFile);
      fs.closeSync(destFile);
      return true;
    } catch (err) {
      console.error('[Crypto] Decrypt failed:', JSON.stringify(err));
      return false;
    }
  }

  static async encryptData(data: string, password: string): Promise<string> {
    try {
      const salt = CryptoUtil.generateSalt();
      const symKeyGenerator = cryptoFramework.createSymKeyGenerator('AES256');
      const md = cryptoFramework.createMd('SHA256');
      const pwdBytes = stringToUint8Array(password);
      const material = new Uint8Array(pwdBytes.length + salt.length);
      material.set(pwdBytes, 0);
      material.set(salt, pwdBytes.length);
      await md.update({ data: material });
      const digest = await md.digest();
      const symKey = await symKeyGenerator.convertKey({ data: digest.data });

      const iv = new Uint8Array(IV_LENGTH);
      for (let i = 0; i < IV_LENGTH; i++) {
        iv[i] = Math.floor(Math.random() * 256);
      }
      const params = createIvParamsSpec(iv);

      const cipher = cryptoFramework.createCipher('AES256|CBC|PKCS7');
      await cipher.init(cryptoFramework.CryptoMode.ENCRYPT_MODE, symKey, params);

      const plainData = stringToUint8Array(data);
      const encrypted = await cipher.doFinal({ data: plainData });

      const combined = new Uint8Array(SALT_LENGTH + IV_LENGTH + encrypted.data.length);
      combined.set(salt, 0);
      combined.set(iv, SALT_LENGTH);
      combined.set(encrypted.data, SALT_LENGTH + IV_LENGTH);

      const base64 = new util.Base64Helper();
      return base64.encodeToString(combined);
    } catch (err) {
      console.error('[Crypto] Encrypt data failed:', JSON.stringify(err));
      return '';
    }
  }

  static async decryptData(encryptedBase64: string, password: string): Promise<string> {
    try {
      const base64 = new util.Base64Helper();
      const combined = base64.decodeSync(encryptedBase64);

      const salt = new Uint8Array(combined.buffer, 0, SALT_LENGTH);
      const iv = new Uint8Array(combined.buffer, SALT_LENGTH, IV_LENGTH);
      const cipherData = new Uint8Array(combined.buffer, SALT_LENGTH + IV_LENGTH);

      const symKeyGenerator = cryptoFramework.createSymKeyGenerator('AES256');
      const md = cryptoFramework.createMd('SHA256');
      const pwdBytes = stringToUint8Array(password);
      const material = new Uint8Array(pwdBytes.length + salt.length);
      material.set(pwdBytes, 0);
      material.set(salt, pwdBytes.length);
      await md.update({ data: material });
      const digest = await md.digest();
      const symKey = await symKeyGenerator.convertKey({ data: digest.data });

      const cipher = cryptoFramework.createCipher('AES256|CBC|PKCS7');
      const params = createIvParamsSpec(iv);
      await cipher.init(cryptoFramework.CryptoMode.DECRYPT_MODE, symKey, params);

      const decrypted = await cipher.doFinal({ data: cipherData });
      return uint8ArrayToString(decrypted.data);
    } catch (err) {
      console.error('[Crypto] Decrypt data failed:', JSON.stringify(err));
      return '';
    }
  }
}

function simpleHash(input: string): string {
  let hash = 0;
  for (let i = 0; i < input.length; i++) {
    const ch = input.charCodeAt(i);
    hash = ((hash << 5) - hash) + ch;
    hash = hash & hash;
  }
  return hash.toString(16);
}
