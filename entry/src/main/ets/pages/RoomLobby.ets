import { router } from '@kit.ArkUI';
import { ActionResult, GameDefinition, RoomPlayer } from '../core/GameContracts';
import { RoomSession } from '../core/RoomEngine';
import { NearbyGameService } from '../services/NearbyGameService';
import { PartyAppStore } from '../viewmodels/PartyAppStore';

@Entry
@Component
struct RoomLobby {
  @State players: RoomPlayer[] = [];
  @State roomCode: string = '';
  @State targetPlayers: number = 2;
  @State message: string = '';
  @State definition: GameDefinition = PartyAppStore.getInstance().selectedDefinition();
  private store: PartyAppStore = PartyAppStore.getInstance();
  private nearby: NearbyGameService = NearbyGameService.getInstance();

  aboutToAppear(): void {
    this.refresh();
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
          .backgroundColor('#F1E4CF')
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
            Text('把设备依次交给同桌玩家即可开始')
              .fontSize(11)
              .fontColor('#ECD9BF')
          }
          .width('100%')
          .padding(19)
          .borderRadius(22)
          .backgroundColor('#5D3C29')

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
                .backgroundColor('#8B5A3C')
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
          .backgroundColor('#FFFDF8')

          Text(this.message)
            .width('100%')
            .fontSize(12)
            .fontColor('#765B48')
            .padding(12)
            .borderRadius(13)
            .backgroundColor('#F1E4CF')

          Button('开始游戏')
            .width('100%')
            .height(52)
            .fontSize(16)
            .backgroundColor('#6B4330')
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
    .backgroundColor('#FAF4E9')
  }
}
