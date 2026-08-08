import { router } from '@kit.ArkUI';
import { ActionResult, GameDefinition, RoomPlayer } from '../core/GameContracts';
import { RoomSession } from '../core/RoomEngine';
import { EnvelopeKind, RoomEnvelopeV3, RoomProtocolV3 } from '../core/RoomProtocol';
import { RoomTransportConfig, RoomTransportListener } from '../core/RoomTransport';
import { LanRoomTransport } from '../services/LanRoomTransport';
import { NearbyGameService } from '../services/NearbyGameService';
import { PartyAppStore } from '../viewmodels/PartyAppStore';

class HostRoomListener implements RoomTransportListener {
  private envelopeCallback: (envelope: RoomEnvelopeV3) => void;
  private stateCallback: (message: string) => void;

  constructor(envelopeCallback: (envelope: RoomEnvelopeV3) => void, stateCallback: (message: string) => void) {
    this.envelopeCallback = envelopeCallback;
    this.stateCallback = stateCallback;
  }

  public onEnvelope(envelope: RoomEnvelopeV3): void {
    this.envelopeCallback(envelope);
  }

  public onTransportState(message: string): void {
    this.stateCallback(message);
  }
}

@Entry
@Component
struct RoomLobby {
  @State players: RoomPlayer[] = [];
  @State roomCode: string = '';
  @State targetPlayers: number = 2;
  @State message: string = '';
  @State knockReady: boolean = false;
  @State definition: GameDefinition = PartyAppStore.getInstance().selectedDefinition();
  private store: PartyAppStore = PartyAppStore.getInstance();
  private nearby: NearbyGameService = NearbyGameService.getInstance();
  private lan: LanRoomTransport = new LanRoomTransport();
  private protocol: RoomProtocolV3 = new RoomProtocolV3();
  private inviteReady: boolean = false;
  private hostListener: HostRoomListener = new HostRoomListener((envelope: RoomEnvelopeV3) => {
    this.handleHostEnvelope(envelope);
  }, (value: string) => {
    this.message = value;
  });

  aboutToAppear(): void {
    this.refresh();
    this.prepareInviteChannel();
  }

  aboutToDisappear(): void {
    this.lan.stop().catch(() => {
      return;
    });
    this.nearby.shutdown().catch(() => {
      return;
    });
  }

  private refresh(): void {
    const session: RoomSession | null = this.store.session();
    if (session !== null) {
      this.players = session.players.slice();
      this.roomCode = session.roomCode;
      this.targetPlayers = session.targetPlayers;
      this.definition = this.store.selectedDefinition();
      this.nearby.configure(session.roomCode, session.gameId, session.targetPlayers);
    }
    this.message = this.store.message;
  }

  private addLocal(): void {
    this.store.addLocalPlayer();
    this.refresh();
  }

  private fillPlayers(): void {
    this.store.fillLocalPlayers();
    this.refresh();
  }

  private addAi(normal: boolean): void {
    this.store.addAi(normal);
    this.refresh();
  }

  private fillAi(normal: boolean): void {
    this.store.fillAiPlayers(normal);
    this.refresh();
  }

  private startGame(): void {
    const result: ActionResult = this.store.startGame();
    this.message = result.message;
    if (result.success) {
      router.pushUrl({ url: 'pages/GameRoom' });
    }
  }

  private async prepareInviteChannel(): Promise<void> {
    if (this.inviteReady) {
      await this.enableKnockInvite();
      return;
    }
    const session: RoomSession | null = this.store.session();
    if (session === null) {
      this.message = '房间不存在，请返回重新创建';
      return;
    }
    const config: RoomTransportConfig = new RoomTransportConfig();
    config.roomCode = session.roomCode;
    config.localPlayerId = session.hostId;
    const result: ActionResult = await this.lan.startHost(config, this.hostListener);
    if (!result.success) {
      this.message = result.message;
      return;
    }
    this.nearby.setInviteCredential(this.lan.inviteCredential());
    this.inviteReady = true;
    await this.enableKnockInvite();
  }

  private async enableKnockInvite(): Promise<void> {
    const result: ActionResult = await this.nearby.enableKnock();
    this.knockReady = result.success;
    this.message = result.message;
  }

  private async shareInvite(): Promise<void> {
    if (!this.inviteReady) {
      await this.prepareInviteChannel();
    }
    const result: ActionResult = await this.nearby.shareRoom();
    this.message = result.message;
  }

  private handleHostEnvelope(envelope: RoomEnvelopeV3): void {
    const session: RoomSession | null = this.store.session();
    if (session === null || envelope.roomCode !== session.roomCode || envelope.kind !== EnvelopeKind.JOIN) {
      return;
    }
    const result: ActionResult = this.store.addRemotePlayer(envelope.senderId, envelope.payload);
    this.refresh();
    this.message = result.message;
    this.sendJoinSnapshot(envelope.senderId).catch(() => {
      this.message = '玩家已入席，但状态确认发送失败';
    });
  }

  private async sendJoinSnapshot(playerId: string): Promise<void> {
    const session: RoomSession | null = this.store.session();
    if (session === null) {
      return;
    }
    const envelope: RoomEnvelopeV3 = new RoomEnvelopeV3();
    envelope.roomCode = session.roomCode;
    envelope.senderId = session.hostId;
    envelope.messageId = 'join-' + playerId + '-' + Date.now().toString(36);
    envelope.revision = session.revision;
    envelope.kind = EnvelopeKind.SNAPSHOT;
    envelope.payload = this.definition.title + '|' + this.players.length.toString() + '|' +
      session.targetPlayers.toString();
    envelope.checksum = this.protocol.checksum(envelope.payload);
    await this.lan.send(envelope);
  }

  @Builder
  PlayerSeat(player: RoomPlayer) {
    Column({ space: 5 }) {
      Text(player.nickname.substring(0, 1))
        .width(42)
        .height(42)
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor('#4D3323')
        .textAlign(TextAlign.Center)
        .padding({ top: 10 })
        .borderRadius(21)
        .backgroundColor(player.host ? '#F2D7A9' : '#E9E0D3')
      Text(player.nickname)
        .fontSize(11)
        .maxLines(1)
      Text(player.host ? '房主' : player.seat.toString() + ' 号位')
        .fontSize(9)
        .fontColor('#8A715E')
    }
    .width(68)
  }

  build() {
    Column() {
      Row() {
        Button('‹')
          .width(42)
          .height(38)
          .fontSize(24)
          .fontColor('#493022')
          .border({ width: 1, color: '#CCFFFFFF' })
          .backgroundColor('#BFFFFFFF')
          .onClick(() => {
            router.back();
          })
        Column({ space: 2 }) {
          Text(this.definition.title + ' 房间')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
          Text('本机热座房间')
            .fontSize(9)
            .fontColor('#7C6250')
        }
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 12 })
        .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 10 })
      .border({ width: { bottom: 1 }, color: '#66FFFFFF' })
      .backgroundColor('#70FFFFFF')
      .backgroundBlurStyle(BlurStyle.Thick)
      .shadow({ radius: 18, color: '#140A254A', offsetY: 5 })

      Scroll() {
        Column({ space: 14 }) {
          Column({ space: 6 }) {
            Text('房间码')
              .fontSize(12)
              .fontColor('#876E5A')
            Text(this.roomCode)
              .fontSize(34)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFF8EA')
              .letterSpacing(3)
              .copyOption(CopyOptions.LocalDevice)
            Text('碰一碰或分享链接，好友可直接入席')
              .fontSize(11)
              .fontColor('#ECD9BF')
          }
          .width('100%')
          .padding(19)
          .borderRadius(22)
          .border({ width: 1, color: '#66FFFFFF' })
          .backgroundColor('#B85D3C29')
          .backgroundBlurStyle(BlurStyle.Thin)
          .shadow({ radius: 22, color: '#2213253F', offsetY: 8 })

          Column({ space: 10 }) {
            Row() {
              Column({ space: 3 }) {
                Text('碰一碰加入棋局')
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#2F2219')
                Text(this.knockReady ? '已就绪 · 保持本页在前台并让两台设备轻碰' : '正在准备临时加密入局凭据')
                  .fontSize(11)
                  .fontColor(this.knockReady ? '#2E6848' : '#806650')
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              Text(this.knockReady ? '已开启' : '准备中')
                .fontSize(10)
                .fontColor(this.knockReady ? '#FFF8EA' : '#6A5140')
                .padding({ left: 9, right: 9, top: 5, bottom: 5 })
                .borderRadius(12)
                .backgroundColor(this.knockReady ? '#3F7557' : '#E9D8BC')
            }
            Row({ space: 8 }) {
              Button(this.knockReady ? '重新开启碰一碰' : '开启碰一碰')
                .layoutWeight(1)
                .height(44)
                .fontSize(12)
                .backgroundColor('#0A59F7')
                .onClick(() => {
                  this.enableKnockInvite();
                })
              Button('系统分享')
                .layoutWeight(1)
                .height(44)
                .fontSize(12)
                .fontColor('#4D3323')
                .border({ width: 1, color: '#B3FFFFFF' })
                .backgroundColor('#BFFFFFFF')
                .onClick(() => {
                  this.shareInvite();
                })
            }
          }
          .width('100%')
          .padding(16)
          .borderRadius(20)
          .border({ width: 1, color: '#CCFFFFFF' })
          .backgroundColor('#D9FFFFFF')
          .shadow({ radius: 16, color: '#140A254A', offsetY: 5 })

          Column({ space: 12 }) {
            Row() {
              Text('玩家席位')
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .layoutWeight(1)
              Text(this.players.length.toString() + '/' + this.targetPlayers.toString())
                .fontSize(12)
                .fontColor('#956647')
            }
            Scroll() {
              Row({ space: 6 }) {
                ForEach(this.players, (player: RoomPlayer) => {
                  this.PlayerSeat(player)
                }, (player: RoomPlayer) => player.id)
              }
            }
            .scrollable(ScrollDirection.Horizontal)
            .scrollBar(BarState.Off)
            .width('100%')
            Row({ space: 8 }) {
              Button('添加本机玩家')
                .layoutWeight(1)
                .height(40)
                .fontSize(11)
                .fontColor('#4D3323')
                .backgroundColor('#F1E4CF')
                .onClick(() => {
                  this.addLocal();
                })
              Button('一键补齐')
                .layoutWeight(1)
                .height(40)
                .fontSize(11)
                .backgroundColor('#0A59F7')
                .onClick(() => {
                  this.fillPlayers();
                })
            }
            if (this.definition.supportsAi) {
              Row({ space: 8 }) {
                Button('简单 AI')
                  .layoutWeight(1)
                  .height(38)
                  .fontSize(11)
                  .fontColor('#32583F')
                  .backgroundColor('#E2EEE3')
                  .onClick(() => {
                    this.addAi(false);
                  })
                Button('普通 AI')
                  .layoutWeight(1)
                  .height(38)
                  .fontSize(11)
                  .fontColor('#32583F')
                  .backgroundColor('#D5E8D8')
                  .onClick(() => {
                    this.addAi(true);
                  })
                Button('AI 补齐')
                  .layoutWeight(1)
                  .height(38)
                  .fontSize(11)
                  .fontColor('#FFF8E7')
                  .backgroundColor('#49745B')
                  .onClick(() => {
                    this.fillAi(true);
                  })
              }
            }
          }
          .width('100%')
          .padding(16)
          .borderRadius(20)
          .border({ width: 1, color: '#CCFFFFFF' })
          .backgroundColor('#D9FFFFFF')
          .shadow({ radius: 16, color: '#140A254A', offsetY: 5 })

          Text(this.message)
            .width('100%')
            .fontSize(12)
            .fontColor('#765B48')
            .padding(12)
            .borderRadius(13)
            .border({ width: 1, color: '#B3FFFFFF' })
            .backgroundColor('#BFFFFFFF')

          Button('开始游戏')
            .width('100%')
            .height(52)
            .fontSize(16)
            .backgroundColor('#0A59F7')
            .onClick(() => {
              this.startGame();
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 28 })
      }
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .linearGradient({
      direction: GradientDirection.Bottom,
      repeating: false,
      colors: [['#F8FBFF', 0.0], ['#EAF2FF', 0.5], ['#FAF4E9', 1.0]]
    })
  }
}
