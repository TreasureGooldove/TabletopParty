import { router } from '@kit.ArkUI';
import { GameCategory, GameDefinition } from '../core/GameContracts';
import { GameCatalog } from '../games/GameCatalog';
import { PartyAppStore } from '../viewmodels/PartyAppStore';

@Entry
@Component
struct Index {
  @State games: GameDefinition[] = [];
  @State partyGames: GameDefinition[] = [];
  @State selectedCategory: string = 'all';
  @State query: string = '';
  @State message: string = '面对面开局，不用等网络';
  @State pageWidth: number = 390;
  private store: PartyAppStore = PartyAppStore.getInstance();

  aboutToAppear(): void {
    this.rebuildGames();
    this.partyGames = GameCatalog.partyTools();
    this.message = this.store.message;
  }

  private rebuildGames(): void {
    const source: GameDefinition[] = GameCatalog.featured();
    const result: GameDefinition[] = [];
    for (let index: number = 0; index < source.length; index += 1) {
      const categoryMatches: boolean = this.selectedCategory === 'all' ||
        source[index].category === this.selectedCategory;
      const queryMatches: boolean = this.query.trim().length === 0 ||
        source[index].title.indexOf(this.query.trim()) >= 0 || source[index].summary.indexOf(this.query.trim()) >= 0;
      if (categoryMatches && queryMatches) {
        result.push(source[index]);
      }
    }
    this.games = result;
  }

  private openGame(game: GameDefinition): void {
    this.store.selectGame(game.id);
    this.message = '正在打开 ' + game.title;
    router.pushUrl({ url: 'pages/GameDetail' });
  }

  @Builder
  Header() {
    Column({ space: 14 }) {
      Image($r('app.media.party_hero'))
        .width('100%')
        .height(this.pageWidth >= 720 ? 230 : 142)
        .objectFit(ImageFit.Cover)
        .borderRadius(18)
        .accessibilityText('东方桌游派对原创插画')
      Row() {
        Column({ space: 5 }) {
          Text('桌游派对')
            .fontSize(30)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFF8EA')
          Text('围一桌，就开局')
            .fontSize(14)
            .fontColor('#E9D5B5')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Text('牌 · 棋 · 推理')
          .fontSize(11)
          .fontColor('#573621')
          .padding({ left: 12, right: 12, top: 7, bottom: 7 })
          .borderRadius(16)
          .backgroundColor('#F4D7A5')
      }
      Text('12 款主游戏与 3 个派对玩法，本机热座无需账号，棋盘、牌面与题库均可离线使用。')
        .fontSize(13)
        .lineHeight(20)
        .fontColor('#F5E8D2')
      Row({ space: 8 }) {
        this.CapabilityPill('热座', '离线可玩')
        this.CapabilityPill('原创', '专属牌面')
        this.CapabilityPill('AI', '三款棋类')
      }
    }
    .width('100%')
    .padding(20)
    .borderRadius(24)
    .backgroundColor('#543826')
  }

  @Builder
  CapabilityPill(title: string, subtitle: string) {
    Column({ space: 2 }) {
      Text(title)
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor('#4A2E1D')
      Text(subtitle)
        .fontSize(9)
        .fontColor('#7B5A43')
    }
    .layoutWeight(1)
    .padding({ top: 8, bottom: 8 })
    .borderRadius(12)
    .backgroundColor('#F8E9CD')
  }

  @Builder
  CategoryBar() {
    Scroll() {
      Row({ space: 8 }) {
        this.CategoryChip('all', '全部')
        this.CategoryChip(GameCategory.BOARD, '棋类')
        this.CategoryChip(GameCategory.CARD, '牌类')
        this.CategoryChip(GameCategory.DEDUCTION, '推理')
        this.CategoryChip(GameCategory.PARTY, '聚会')
      }
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
  }

  @Builder
  CategoryChip(id: string, title: string) {
    Text(title)
      .fontSize(12)
      .fontWeight(this.selectedCategory === id ? FontWeight.Bold : FontWeight.Regular)
      .fontColor(this.selectedCategory === id ? '#FFF8EA' : '#604633')
      .padding({ left: 16, right: 16, top: 9, bottom: 9 })
      .borderRadius(18)
      .backgroundColor(this.selectedCategory === id ? '#6B4330' : '#F1E4CF')
      .onClick(() => {
        this.selectedCategory = id;
        this.rebuildGames();
      })
  }

  @Builder
  GameCard(game: GameDefinition) {
    Row({ space: 14 }) {
      Text(game.iconText)
        .width(52)
        .height(52)
        .fontSize(23)
        .fontWeight(FontWeight.Bold)
        .fontColor('#4D3323')
        .textAlign(TextAlign.Center)
        .padding({ top: 12 })
        .borderRadius(16)
        .backgroundColor(game.accent)
      Column({ space: 5 }) {
        Row({ space: 8 }) {
          Text(game.title)
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor('#2D2119')
          if (game.supportsAi) {
            Text('AI')
              .fontSize(9)
              .fontColor('#2E6848')
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .borderRadius(8)
              .backgroundColor('#DCECDD')
          }
        }
        Text(game.summary)
          .fontSize(12)
          .fontColor('#745F4F')
          .maxLines(1)
        Text(game.minPlayers.toString() + '–' + game.maxPlayers.toString() + ' 人')
          .fontSize(10)
          .fontColor('#A16945')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Text('›')
        .fontSize(24)
        .fontColor('#B49478')
    }
    .width('100%')
    .padding(14)
    .borderRadius(20)
    .backgroundColor('#FFFDF8')
    .shadow({ radius: 12, color: '#14000000', offsetY: 4 })
    .onClick(() => {
      this.openGame(game);
    })
  }

  @Builder
  GameHall() {
    Scroll() {
      Column({ space: 14 }) {
        this.Header()
        TextInput({ text: this.query, placeholder: '搜索象棋、狼人杀、麻将…' })
          .height(46)
          .padding({ left: 14, right: 14 })
          .borderRadius(16)
          .backgroundColor('#FFFDF8')
          .onChange((value: string) => {
            this.query = value;
            this.rebuildGames();
          })
        this.CategoryBar()
        Row() {
          Text('精选游戏')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#332319')
            .layoutWeight(1)
          Text(this.games.length.toString() + ' 款可玩')
            .fontSize(11)
            .fontColor('#8A715E')
        }
        if (this.pageWidth >= 700) {
          Grid() {
            ForEach(this.games, (game: GameDefinition) => {
              GridItem() {
                this.GameCard(game)
              }
            }, (game: GameDefinition) => game.id)
          }
          .columnsTemplate('1fr 1fr')
          .columnsGap(14)
          .rowsGap(14)
          .width('100%')
        } else {
          Column({ space: 11 }) {
            ForEach(this.games, (game: GameDefinition) => {
              this.GameCard(game)
            }, (game: GameDefinition) => game.id)
          }
          .width('100%')
        }
        Text(this.message)
          .width('100%')
          .fontSize(11)
          .fontColor('#7A624F')
          .padding(12)
          .borderRadius(14)
          .backgroundColor('#F1E4CF')
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 30 })
    }
    .scrollBar(BarState.Off)
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      this.pageWidth = Number(newValue.width);
    })
  }

  @Builder
  PartyHall() {
    Scroll() {
      Column({ space: 14 }) {
        Column({ space: 7 }) {
          Text('派对工具箱')
            .fontSize(25)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFF8EA')
          Text('不需要复杂规则，随时热场')
            .fontSize(13)
            .fontColor('#F2DEC0')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(20)
        .borderRadius(22)
        .backgroundColor('#7A4B58')
        ForEach(this.partyGames, (game: GameDefinition) => {
          this.GameCard(game)
        }, (game: GameDefinition) => game.id)
      }
      .padding(16)
    }
    .scrollBar(BarState.Off)
  }

  @Builder
  LibraryTab() {
    Column({ space: 16 }) {
      Text('内容库')
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .fontColor('#332319')
      Text('卧底、画猜、演猜和派对题库均为原创内容，并支持导入本地 ContentPackV1。')
        .fontSize(14)
        .lineHeight(22)
        .fontColor('#745F4F')
      Button('查看内容库')
        .width('100%')
        .height(48)
        .backgroundColor('#6B4330')
        .onClick(() => {
          router.pushUrl({ url: 'pages/ContentLibrary' });
        })
    }
    .width('100%')
    .padding(22)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ProfileTab() {
    Column({ space: 13 }) {
      Text('我的桌游间')
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .fontColor('#332319')
      this.ProfileAction('本地战绩', '只记录游戏、人数与结果，不保存身份和手牌', 'pages/Stats')
      this.ProfileAction('偏好设置', '大字、减少动画、振动与私密遮罩', 'pages/Settings')
      Text('所有可见房间均为本机热座运行，不需要账号。结束房间后会清除私密对局状态。')
        .fontSize(12)
        .lineHeight(19)
        .fontColor('#7A624F')
        .padding(14)
        .borderRadius(14)
        .backgroundColor('#F1E4CF')
    }
    .width('100%')
    .padding(18)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ProfileAction(title: string, subtitle: string, url: string) {
    Row() {
      Column({ space: 4 }) {
        Text(title)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
        Text(subtitle)
          .fontSize(11)
          .fontColor('#7A624F')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Text('›')
        .fontSize(24)
        .fontColor('#A37C60')
    }
    .width('100%')
    .padding(16)
    .borderRadius(18)
    .backgroundColor('#FFFDF8')
    .onClick(() => {
      router.pushUrl({ url: url });
    })
  }

  build() {
    Tabs({ barPosition: BarPosition.End }) {
      TabContent() {
        this.GameHall()
      }
      .tabBar('游戏')

      TabContent() {
        this.PartyHall()
      }
      .tabBar('派对')

      TabContent() {
        this.LibraryTab()
      }
      .tabBar('内容')

      TabContent() {
        this.ProfileTab()
      }
      .tabBar('我的')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FAF4E9')
    .barBackgroundColor('#FFFDF8')
  }
}
