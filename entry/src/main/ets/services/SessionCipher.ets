import { util } from '@kit.ArkTS';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';

export class EncryptedPacket {
  public iv: Uint8Array = new Uint8Array(0);
  public authTag: Uint8Array = new Uint8Array(0);
  public payload: Uint8Array = new Uint8Array(0);
}

export class SessionCipher {
  private key: cryptoFramework.SymKey | null = null;
  private base64: util.Base64Helper = new util.Base64Helper();

  public async createKey(): Promise<void> {
    const generator: cryptoFramework.SymKeyGenerator = cryptoFramework.createSymKeyGenerator('AES256');
    this.key = await generator.generateSymKey();
  }

  public importCredential(value: string): boolean {
    try {
      const bytes: Uint8Array = this.base64.decodeSync(value, util.Type.BASIC_URL_SAFE);
      if (bytes.length !== 32) {
        return false;
      }
      const generator: cryptoFramework.SymKeyGenerator = cryptoFramework.createSymKeyGenerator('AES256');
      const blob: cryptoFramework.DataBlob = { data: bytes };
      this.key = generator.convertKeySync(blob);
      return true;
    } catch (error) {
      this.key = null;
      return false;
    }
  }

  public exportCredential(): string {
    if (this.key === null) {
      return '';
    }
    return this.base64.encodeToStringSync(this.key.getEncoded().data, util.Type.BASIC_URL_SAFE);
  }

  public async encrypt(text: string, associatedText: string): Promise<string> {
    if (this.key === null) {
      throw new Error('Session key is not ready');
    }
    const encoder: util.TextEncoder = util.TextEncoder.create('utf-8');
    const random: cryptoFramework.Random = cryptoFramework.createRandom();
    const iv: cryptoFramework.DataBlob = await random.generateRandom(12);
    const params: cryptoFramework.GcmParamsSpec = {
      algName: 'GcmParamsSpec',
      iv: iv,
      aad: { data: encoder.encodeInto(associatedText) },
      authTag: { data: new Uint8Array(0) }
    };
    const cipher: cryptoFramework.Cipher = cryptoFramework.createCipher('AES256|GCM|NoPadding');
    await cipher.init(cryptoFramework.CryptoMode.ENCRYPT_MODE, this.key, params);
    const output: cryptoFramework.DataBlob = await cipher.doFinal({ data: encoder.encodeInto(text) });
    return 'SEC1|' + this.base64.encodeToStringSync(iv.data, util.Type.BASIC_URL_SAFE) + '|' +
      this.base64.encodeToStringSync(params.authTag.data, util.Type.BASIC_URL_SAFE) + '|' +
      this.base64.encodeToStringSync(output.data, util.Type.BASIC_URL_SAFE);
  }

  public async decrypt(text: string, associatedText: string): Promise<string> {
    if (this.key === null) {
      throw new Error('Session key is not ready');
    }
    const fields: string[] = text.split('|');
    if (fields.length !== 4 || fields[0] !== 'SEC1') {
      throw new Error('Encrypted packet is invalid');
    }
    const encoder: util.TextEncoder = util.TextEncoder.create('utf-8');
    const params: cryptoFramework.GcmParamsSpec = {
      algName: 'GcmParamsSpec',
      iv: { data: this.base64.decodeSync(fields[1], util.Type.BASIC_URL_SAFE) },
      aad: { data: encoder.encodeInto(associatedText) },
      authTag: { data: this.base64.decodeSync(fields[2], util.Type.BASIC_URL_SAFE) }
    };
    const cipher: cryptoFramework.Cipher = cryptoFramework.createCipher('AES256|GCM|NoPadding');
    await cipher.init(cryptoFramework.CryptoMode.DECRYPT_MODE, this.key, params);
    const encrypted: cryptoFramework.DataBlob = {
      data: this.base64.decodeSync(fields[3], util.Type.BASIC_URL_SAFE)
    };
    const output: cryptoFramework.DataBlob = await cipher.doFinal(encrypted);
    const decoder: util.TextDecoder = util.TextDecoder.create('utf-8');
    return decoder.decodeToString(output.data);
  }

  public clear(): void {
    this.key = null;
  }
}
