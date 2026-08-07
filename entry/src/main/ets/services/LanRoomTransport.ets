import { util } from '@kit.ArkTS';
import { socket } from '@kit.NetworkKit';
import { ActionResult, TransportKind } from '../core/GameContracts';
import { RoomEnvelopeV3, RoomProtocolV3 } from '../core/RoomProtocol';
import { RoomTransport, RoomTransportConfig, RoomTransportListener } from '../core/RoomTransport';
import { SessionCipher } from './SessionCipher';

export class LanRoomTransport implements RoomTransport {
  private static readonly PORT: number = 37989;
  private static readonly BROADCAST: string = '255.255.255.255';
  private udpSocket: socket.UDPSocket | null = null;
  private listener: RoomTransportListener | null = null;
  private roomCode: string = '';
  private hostAddress: string = '';
  private host: boolean = false;
  private protocol: RoomProtocolV3 = new RoomProtocolV3();
  private cipher: SessionCipher = new SessionCipher();

  private socketCallback = (info: socket.SocketMessageInfo): void => {
    if (this.listener === null) {
      return;
    }
    const decoder: util.TextDecoder = util.TextDecoder.create('utf-8');
    const encryptedText: string = decoder.decodeToString(new Uint8Array(info.message));
    this.cipher.decrypt(encryptedText, this.roomCode).then((plainText: string) => {
      const envelope: RoomEnvelopeV3 | null = this.protocol.decode(plainText);
      if (envelope !== null && envelope.roomCode === this.roomCode && this.listener !== null) {
        if (!this.host) {
          this.hostAddress = info.remoteInfo.address;
        }
        this.listener.onEnvelope(envelope);
      }
    }).catch(() => {
      if (this.listener !== null) {
        this.listener.onTransportState('收到无法校验的局域网数据，已丢弃');
      }
    });
  };

  public kind(): TransportKind {
    return TransportKind.LAN;
  }

  public async startHost(config: RoomTransportConfig, listener: RoomTransportListener): Promise<ActionResult> {
    await this.stop();
    this.roomCode = config.roomCode;
    this.listener = listener;
    this.host = true;
    await this.cipher.createKey();
    return this.openSocket('同一 Wi‑Fi 加密房间已开启');
  }

  public async join(config: RoomTransportConfig, listener: RoomTransportListener): Promise<ActionResult> {
    await this.stop();
    this.roomCode = config.roomCode;
    this.listener = listener;
    this.host = false;
    if (!this.cipher.importCredential(config.inviteCredential)) {
      return new ActionResult(false, '临时入局凭据无效，不能用房间码代替密钥');
    }
    return this.openSocket('已开启同一 Wi‑Fi 加密通道');
  }

  public async send(envelope: RoomEnvelopeV3): Promise<ActionResult> {
    const activeSocket: socket.UDPSocket | null = this.udpSocket;
    if (activeSocket === null) {
      return new ActionResult(false, '局域网通道尚未启动');
    }
    try {
      const encrypted: string = await this.cipher.encrypt(this.protocol.encode(envelope), this.roomCode);
      const address: socket.NetAddress = {
        address: this.hostAddress.length > 0 ? this.hostAddress : LanRoomTransport.BROADCAST,
        family: 1,
        port: LanRoomTransport.PORT
      };
      await activeSocket.send({ data: encrypted, address: address });
      return new ActionResult(true, '加密动作已发送');
    } catch (error) {
      return new ActionResult(false, '局域网发送失败');
    }
  }

  public inviteCredential(): string {
    return this.cipher.exportCredential();
  }

  public async stop(): Promise<void> {
    const activeSocket: socket.UDPSocket | null = this.udpSocket;
    this.udpSocket = null;
    if (activeSocket !== null) {
      try {
        activeSocket.off('message', this.socketCallback);
        await activeSocket.close();
      } catch (error) {
        return;
      }
    }
    this.listener = null;
    this.roomCode = '';
    this.hostAddress = '';
    this.host = false;
    this.cipher.clear();
  }

  private async openSocket(successMessage: string): Promise<ActionResult> {
    try {
      const instance: socket.UDPSocket = socket.constructUDPSocketInstance();
      instance.on('message', this.socketCallback);
      const address: socket.NetAddress = { address: '0.0.0.0', family: 1, port: LanRoomTransport.PORT };
      await instance.bind(address);
      await instance.setExtraOptions({ broadcast: true });
      this.udpSocket = instance;
      if (this.listener !== null) {
        this.listener.onTransportState(successMessage);
      }
      return new ActionResult(true, successMessage);
    } catch (error) {
      this.udpSocket = null;
      return new ActionResult(false, 'Wi‑Fi 通道启动失败，可继续使用星闪或热座');
    }
  }
}
