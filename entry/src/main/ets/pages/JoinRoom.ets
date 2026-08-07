import { router } from '@kit.ArkUI';
import { ActionResult, GameDefinition } from '../core/GameContracts';
import { EnvelopeKind, RoomEnvelopeV3, RoomProtocolV3 } from '../core/RoomProtocol';
import { RoomTransportConfig, RoomTransportListener } from '../core/RoomTransport';
import { GameCatalog } from '../games/GameCatalog';
import { LanRoomTransport } from '../services/LanRoomTransport';
import { NearbyGameService, NearbyRoomInfo } from '../services/NearbyGameService';
import { RoomInvite } from '../services/RoomInviteService';
import { PartyAppStore } from '../viewmodels/PartyAppStore';

class JoinListener implements RoomTransportListener {
  private callback: (message: string) => void;

  constructor(callback: (message: string) => void) {
    this.callback = callback;
  }

  public onEnvelope(envelope: RoomEnvelopeV3): void {
    if (envelope.kind === EnvelopeKind.SNAPSHOT) {
      this.callback('已收到房主状态，版本 ' + envelope.revision.toString());
    }
  }

  public onTransportState(message: string): void {
    this.callback(message);
  }
}

@Entry
@Component
struct JoinRoom {
  @State roomCode: string = '';
  @State title: string = '附近房间';
  @State message: string = '选择星闪直连或同一 Wi-Fi 加入';
  @State rooms: NearbyRoomInfo[] = [];
  private store: PartyAppStore = PartyAppStore.getInstance();
  private nearby: NearbyGameService = NearbyGameService.getInstance();
  private lan: LanRoomTransport = new LanRoomTransport();
  private protocol: RoomProtocolV3 = new RoomProtocolV3();
  private invite: RoomInvite | null = null;
  private localPlayerId: string = 'guest-' + Date.now().toString(36);
  private listener: JoinListener = new JoinListener((value: string) => {
    this.message = value;
  });

  aboutToAppear(): void {
    this.invite = this.store.pendingInvite();
    if (this.invite === null) {
      this.message = '邀请已失效，请让房主重新分享';
      return;
    }
    const definition: GameDefinition = GameCatalog.find(this.invite.gameId);
    this.roomCode = this.invite.roomCode;
    this.title = definition.title;
  }

  aboutToDisappear(): void {
    this.lan.stop().catch(() => {
      return;
    });
  }

  private async joinLan(): Promise<void> {
    if (this.invite === null) {
      this.message = '邀请已失效';
      return;
    }
    const config: RoomTransportConfig = new RoomTransportConfig();
    config.roomCode = this.invite.roomCode;
    config.localPlayerId = this.localPlayerId;
    config.inviteCredential = this.invite.credential;
    const result: ActionResult = await this.lan.join(config, this.listener);
    this.message = result.message;
    if (result.success) {
      await this.sendJoinRequest();
    }
  }

  private async sendJoinRequest(): Promise<void> {
    if (this.invite === null) {
      return;
    }
    const envelope: RoomEnvelopeV3 = new RoomEnvelopeV3();
    envelope.roomCode = this.invite.roomCode;
    envelope.senderId = this.localPlayerId;
    envelope.messageId = this.localPlayerId + '-' + Date.now().toString(36);
    envelope.kind = EnvelopeKind.JOIN;
    envelope.payload = this.store.nickname;
    envelope.checksum = this.protocol.checksum(envelope.payload);
    const result: ActionResult = await this.lan.send(envelope);
    this.message = result.success ? '入局请求已发送，等待房主确认席位' : result.message;
  }

  private async scanNearLink(): Promise<void> {
    const result: ActionResult = await this.nearby.scanRooms();
    this.message = result.message;
    this.rooms = this.nearby.roomResults();
  }

  private async connectNearLink(room: NearbyRoomInfo): Promise<void> {
    const result: ActionResult = await this.nearby.connect(room.address);
    this.message = result.message;
  }

  build() {
    Column() {
      Row() {
        Button('‹')
          .width(42)
          .height(38)
          .fontSize(24)
          .fontColor('#493022')
          .backgroundColor('#F1E4CF')
          .onClick(() => {
            router.back();
          })
        Text('加入附近房间')
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .margin({ left: 12 })
          .layoutWeight(1)
      }
      .width('100%')
      .padding(16)

      Scroll() {
        Column({ space: 14 }) {
          Column({ space: 6 }) {
            Text(this.title)
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFF8EA')
            Text(this.roomCode)
              .fontSize(36)
              .letterSpacing(4)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFF8EA')
            Text('六位房间码仅用于核对，不作为加密密钥')
              .fontSize(11)
              .fontColor('#E8D3AF')
          }
          .width('100%')
          .padding(20)
          .borderRadius(22)
          .backgroundColor('#5D3C29')

          Button('使用同一 Wi-Fi 加密加入')
            .width('100%')
            .height(50)
            .backgroundColor('#6B4330')
            .onClick(() => {
              this.joinLan();
            })
          Button('扫描星闪房间')
            .width('100%')
            .height(48)
            .fontColor('#315C43')
            .backgroundColor('#DCEBDD')
            .onClick(() => {
              this.scanNearLink();
            })

          if (this.rooms.length > 0) {
            ForEach(this.rooms, (room: NearbyRoomInfo) => {
              Row() {
                Column({ space: 3 }) {
                  Text(room.deviceName)
                    .fontSize(14)
                    .fontWeight(FontWeight.Bold)
                  Text(room.roomCode + ' · ' + room.signal.toString() + ' dBm')
                    .fontSize(10)
                    .fontColor('#7A624F')
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                Button('连接')
                  .height(34)
                  .backgroundColor('#7A4B58')
                  .onClick(() => {
                    this.connectNearLink(room);
                  })
              }
              .width('100%')
              .padding(14)
              .borderRadius(16)
              .backgroundColor('#FFFDF8')
            }, (room: NearbyRoomInfo) => room.address)
          }

          Text(this.message)
            .width('100%')
            .fontSize(12)
            .lineHeight(19)
            .fontColor('#765B48')
            .padding(13)
            .borderRadius(14)
            .backgroundColor('#F1E4CF')
          Text('星闪不可用或权限被拒绝时，可返回使用同一 Wi-Fi 或在房主设备上采用热座模式。')
            .fontSize(11)
            .lineHeight(18)
            .fontColor('#806A58')
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 30 })
      }
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FAF4E9')
  }
}
