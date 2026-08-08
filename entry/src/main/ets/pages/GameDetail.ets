import { router } from '@kit.ArkUI';
import { GameDefinition, GameId } from '../core/GameContracts';
import { GameCatalog } from '../games/GameCatalog';
import { PartyAppStore } from '../viewmodels/PartyAppStore';

@Entry
@Component
struct GameDetail {
  @State definition: GameDefinition = GameCatalog.featured()[0];
  @State nickname: string = '玩家';
  @State targetPlayers: number = 4;
  private store: PartyAppStore = PartyAppStore.getInstance();

  aboutToAppear(): void {
    this.definition = this.store.selectedDefinition();
    this.nickname = this.store.nickname;
    this.targetPlayers = this.store.targetPlayers;
  }

  private adjustPlayers(delta: number): void {
    this.targetPlayers = Math.max(this.definition.minPlayers,
      Math.min(this.definition.maxPlayers, this.targetPlayers + delta));
    this.store.targetPlayers = this.targetPlayers;
  }

  private createRoom(): void {
    this.store.nickname = this.nickname;
    this.store.targetPlayers = this.targetPlayers;
    this.store.createRoom();
    router.pushUrl({ url: 'pages/RoomLobby' });
  }

  private openTutorial(): void {
    router.pushUrl({ url: 'pages/Tutorial' });
  }

  @Builder
  GameCover() {
    if (this.definition.id === GameId.UNDERCOVER) {
      Image($r('app.media.cover_undercover')).width('100%').height('100%').objectFit(ImageFit.Cover)
        .accessibilityText('谁是卧底原创封面')
    } else if (this.definition.id === GameId.LANDLORD) {
      Image($r('app.media.cover_landlord')).width('100%').height('100%').objectFit(ImageFit.Cover)
        .accessibilityText('斗地主原创封面')
    } else if (this.definition.id === GameId.CHINESE_CHESS) {
      Image($r('app.media.cover_chinese_chess')).width('100%').height('100%').objectFit(ImageFit.Cover)
        .accessibilityText('中国象棋原创封面')
    } else if (this.definition.id === GameId.JUNQI) {
      Image($r('app.media.cover_junqi')).width('100%').height('100%').objectFit(ImageFit.Cover)
        .accessibilityText('军棋原创封面')
    } else if (this.definition.id === GameId.WEREWOLF) {
      Image($r('app.media.cover_werewolf')).width('100%').height('100%').objectFit(ImageFit.Cover)
        .accessibilityText('狼人杀原创封面')
    } else if (this.definition.id === GameId.COLOR_CLASH) {
      Image($r('app.media.cover_color_clash')).width('100%').height('100%').objectFit(ImageFit.Cover)
        .accessibilityText('彩牌对决原创封面')
    } else if (this.definition.id === GameId.GOMOKU) {
      Image($r('app.media.cover_gomoku')).width('100%').height('100%').objectFit(ImageFit.Cover)
        .accessibilityText('五子棋原创封面')
    } else if (this.definition.id === GameId.REVERSI) {
      Image($r('app.media.cover_reversi')).width('100%').height('100%').objectFit(ImageFit.Cover)
        .accessibilityText('黑白棋原创封面')
    } else if (this.definition.id === GameId.LUDO) {
      Image($r('app.media.cover_ludo')).width('100%').height('100%').objectFit(ImageFit.Cover)
        .accessibilityText('飞行棋原创封面')
    } else if (this.definition.id === GameId.SICHUAN_MAHJONG) {
      Image($r('app.media.cover_sichuan_mahjong')).width('100%').height('100%').objectFit(ImageFit.Cover)
        .accessibilityText('四川麻将原创封面')
    } else if (this.definition.id === GameId.GUANDAN) {
      Image($r('app.media.cover_guandan')).width('100%').height('100%').objectFit(ImageFit.Cover)
        .accessibilityText('掼蛋原创封面')
    } else {
      Image($r('app.media.cover_draw_guess')).width('100%').height('100%').objectFit(ImageFit.Cover)
        .accessibilityText('你画我猜原创封面')
    }
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
        Text('游戏详情')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#332319')
          .margin({ left: 12 })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 10 })
      .border({ width: { bottom: 1 }, color: '#66FFFFFF' })
      .backgroundColor('#70FFFFFF')
      .backgroundBlurStyle(BlurStyle.Thick)
      .shadow({ radius: 18, color: '#140A254A', offsetY: 5 })

      Scroll() {
        Column({ space: 16 }) {
          Column({ space: 12 }) {
            Stack() {
              this.GameCover()
            }
              .width('100%')
              .aspectRatio(2)
              .borderRadius(20)
            Text(this.definition.title)
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor('#2D2119')
            Text(this.definition.summary)
              .fontSize(14)
              .fontColor('#735A48')
          }
          .width('100%')
          .padding(22)
          .borderRadius(24)
          .border({ width: 1, color: '#CCFFFFFF' })
          .backgroundColor('#D9FFFFFF')
          .shadow({ radius: 20, color: '#180A254A', offsetY: 7 })

          Column({ space: 10 }) {
            Text('玩法说明')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#332319')
            Text(this.definition.rules)
              .fontSize(14)
              .lineHeight(23)
              .fontColor('#6F5949')
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(17)
          .borderRadius(20)
          .border({ width: 1, color: '#CCFFFFFF' })
          .backgroundColor('#D9FFFFFF')
          .shadow({ radius: 16, color: '#120A254A', offsetY: 5 })

          Button('教学模式 · 分步学习')
            .width('100%')
            .height(50)
            .fontSize(15)
            .fontColor('#0A59F7')
            .border({ width: 1, color: '#660A59F7' })
            .backgroundColor('#BFFFFFFF')
            .backgroundBlurStyle(BlurStyle.Thin)
            .onClick(() => {
              this.openTutorial();
            })

          Column({ space: 12 }) {
            Text('创建本机房间')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
            TextInput({ text: this.nickname, placeholder: '你的昵称' })
              .height(46)
              .padding({ left: 12, right: 12 })
              .borderRadius(14)
              .border({ width: 1, color: '#B3FFFFFF' })
              .backgroundColor('#99FFFFFF')
              .onChange((value: string) => {
                this.nickname = value;
              })
            Row({ space: 12 }) {
              Text('开局人数')
                .fontSize(14)
                .fontColor('#5F493A')
                .layoutWeight(1)
              Button('−')
                .width(38)
                .height(36)
                .fontColor('#493022')
                .backgroundColor('#F1E4CF')
                .onClick(() => {
                  this.adjustPlayers(-1);
                })
              Text(this.targetPlayers.toString())
                .width(30)
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .textAlign(TextAlign.Center)
              Button('+')
                .width(38)
                .height(36)
                .backgroundColor('#0A59F7')
                .onClick(() => {
                  this.adjustPlayers(1);
                })
            }
            .width('100%')
            if (this.definition.supportsAi) {
              Text('支持简单/普通电脑对手，也可双人热座。')
                .fontSize(11)
                .fontColor('#2E6848')
                .padding(10)
                .borderRadius(12)
                .backgroundColor('#E6F0E6')
            }
            Button('创建房间')
              .width('100%')
              .height(50)
              .fontSize(15)
              .backgroundColor('#0A59F7')
              .onClick(() => {
                this.createRoom();
              })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(17)
          .borderRadius(20)
          .border({ width: 1, color: '#CCFFFFFF' })
          .backgroundColor('#D9FFFFFF')
          .shadow({ radius: 16, color: '#120A254A', offsetY: 5 })
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 30 })
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
