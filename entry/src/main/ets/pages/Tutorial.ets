import { router } from '@kit.ArkUI';
import { ActionResult, GameDefinition, GameId } from '../core/GameContracts';
import { GameCatalog } from '../games/GameCatalog';
import { TutorialCatalog, TutorialStep } from '../services/TutorialCatalog';
import { PartyAppStore } from '../viewmodels/PartyAppStore';

@Entry
@Component
struct Tutorial {
  @State definition: GameDefinition = GameCatalog.featured()[0];
  @State steps: TutorialStep[] = [];
  @State stepIndex: number = 0;
  @State selectedOption: number = -1;
  @State practiceIndex: number = -1;
  @State feedback: string = '按提示直接操作桌面';
  @State pageWidth: number = 390;
  @State pageHeight: number = 844;
  @State landscapeRequested: boolean = false;
  private store: PartyAppStore = PartyAppStore.getInstance();

  aboutToAppear(): void {
    this.definition = this.store.selectedDefinition();
    this.steps = TutorialCatalog.steps(this.definition.id);
    this.stepIndex = 0;
    this.selectedOption = -1;
    this.practiceIndex = -1;
    this.feedback = '按提示直接操作桌面';
    this.store.setGameFullscreen(true).catch(() => {
      return;
    });
    if (this.requiresLandscape()) {
      this.store.setGameLandscape(true).then((result: ActionResult) => {
        this.landscapeRequested = result.success;
      }).catch(() => {
        return;
      });
    }
  }

  aboutToDisappear(): void {
    this.store.setGameFullscreen(false).catch(() => {
      return;
    });
    if (this.landscapeRequested) {
      this.store.setGameLandscape(false).catch(() => {
        return;
      });
    }
  }

  private requiresLandscape(): boolean {
    return this.definition.id === GameId.LANDLORD || this.definition.id === GameId.GUANDAN ||
      this.definition.id === GameId.SICHUAN_MAHJONG || this.definition.id === GameId.CHINESE_CHESS ||
      this.definition.id === GameId.JUNQI;
  }

  private isLandscapeLayout(): boolean {
    return this.pageWidth > this.pageHeight;
  }

  private currentStep(): TutorialStep {
    if (this.steps.length === 0) {
      return new TutorialStep('暂无教学', '教学内容正在准备。', '', '', [], -1);
    }
    return this.steps[Math.max(0, Math.min(this.stepIndex, this.steps.length - 1))];
  }

  private progressIndexes(): number[] {
    const result: number[] = [];
    for (let index: number = 0; index < this.steps.length; index += 1) {
      result.push(index);
    }
    return result;
  }

  private chooseOption(index: number): void {
    this.selectedOption = index;
    this.feedback = index === this.currentStep().correctIndex ? '操作正确，可以进入下一步' : '该操作不符合当前规则，再试一次';
  }

  private selectPractice(index: number, label: string): void {
    this.practiceIndex = index;
    this.feedback = '已在桌面选择：' + label + '。继续完成右侧规则操作。';
  }

  private previous(): void {
    if (this.stepIndex <= 0) {
      return;
    }
    this.stepIndex -= 1;
    this.selectedOption = -1;
    this.practiceIndex = -1;
    this.feedback = '场景已切换，请按新提示操作';
  }

  private next(): void {
    if (this.selectedOption !== this.currentStep().correctIndex) {
      this.feedback = '请先在规则操作区完成本步';
      return;
    }
    if (this.stepIndex >= this.steps.length - 1) {
      router.back();
      return;
    }
    this.stepIndex += 1;
    this.selectedOption = -1;
    this.practiceIndex = -1;
    this.feedback = '新场景已就位，请继续操作';
  }

  private isCardTeaching(): boolean {
    return this.definition.id === GameId.LANDLORD || this.definition.id === GameId.GUANDAN ||
      this.definition.id === GameId.COLOR_CLASH;
  }

  private isBoardTeaching(): boolean {
    return this.definition.id === GameId.CHINESE_CHESS || this.definition.id === GameId.JUNQI ||
      this.definition.id === GameId.GOMOKU || this.definition.id === GameId.REVERSI ||
      this.definition.id === GameId.LUDO;
  }

  private tutorialCards(): string[] {
    if (this.definition.id === GameId.COLOR_CLASH) {
      return ['万能+4', '万能变色', '红+2', '蓝跳', '黄反', '绿9', '红7'];
    }
    return ['大王', '小王', '♠2', '♥A', '♣K', '♦Q', '♠J', '♥10', '♣9'];
  }

  private mahjongTiles(): string[] {
    return ['9万', '8万', '7万', '6万', '5万', '9筒', '8筒', '7筒', '6筒', '9条', '8条', '7条', '6条', '5条'];
  }

  private boardIndexes(): number[] {
    let count: number = 64;
    if (this.definition.id === GameId.CHINESE_CHESS) {
      count = 90;
    } else if (this.definition.id === GameId.JUNQI || this.definition.id === GameId.LUDO) {
      count = 60;
    } else if (this.definition.id === GameId.GOMOKU) {
      count = 225;
    }
    const result: number[] = [];
    for (let index: number = 0; index < count; index += 1) {
      result.push(index);
    }
    return result;
  }

  private boardColumns(): number {
    if (this.definition.id === GameId.CHINESE_CHESS) {
      return 9;
    }
    if (this.definition.id === GameId.JUNQI) {
      return 5;
    }
    if (this.definition.id === GameId.GOMOKU) {
      return 15;
    }
    if (this.definition.id === GameId.LUDO) {
      return 10;
    }
    return 8;
  }

  private boardRows(): number {
    return Math.ceil(this.boardIndexes().length / this.boardColumns());
  }

  private boardSymbol(index: number): string {
    if (this.definition.id === GameId.CHINESE_CHESS) {
      const pieces: number[] = [4, 19, 27, 54, 64, 85];
      const labels: string[] = ['將', '炮', '卒', '兵', '炮', '帥'];
      const position: number = pieces.indexOf(index);
      return position >= 0 ? labels[position] : '';
    }
    if (this.definition.id === GameId.JUNQI) {
      const pieces: number[] = [1, 6, 12, 47, 53, 58];
      const labels: string[] = ['旗', '雷', '司', '工', '炸', '旗'];
      const position: number = pieces.indexOf(index);
      return position >= 0 ? labels[position] : '';
    }
    if (this.definition.id === GameId.GOMOKU) {
      if (index === 111 || index === 112 || index === 113 || index === 114) {
        return '●';
      }
      if (index === 110 || index === 115) {
        return '○';
      }
    } else if (this.definition.id === GameId.REVERSI) {
      if (index === 27 || index === 36) {
        return '○';
      }
      if (index === 28 || index === 35) {
        return '●';
      }
    } else if (this.definition.id === GameId.LUDO && index % 13 === 0) {
      return ((index / 13) + 1).toString();
    }
    return '';
  }

  private boardColor(): string {
    if (this.definition.id === GameId.REVERSI) {
      return '#2D6A48';
    }
    if (this.definition.id === GameId.JUNQI) {
      return '#C79B58';
    }
    if (this.definition.id === GameId.LUDO) {
      return '#E5D7B7';
    }
    return '#D5AA62';
  }

  private colorCardColor(card: string): string {
    if (card.indexOf('红') === 0) {
      return '#C9443B';
    }
    if (card.indexOf('黄') === 0) {
      return '#D7A82C';
    }
    if (card.indexOf('蓝') === 0) {
      return '#3474B8';
    }
    if (card.indexOf('绿') === 0) {
      return '#3C8A55';
    }
    return '#51436F';
  }

  @Builder
  SuitSvg(card: string, size: number) {
    if (card.indexOf('♠') === 0) {
      Image($rawfile('suits/spade.svg')).width(size).height(size).objectFit(ImageFit.Contain)
    } else if (card.indexOf('♥') === 0) {
      Image($rawfile('suits/heart.svg')).width(size).height(size).objectFit(ImageFit.Contain)
    } else if (card.indexOf('♣') === 0) {
      Image($rawfile('suits/club.svg')).width(size).height(size).objectFit(ImageFit.Contain)
    } else if (card.indexOf('♦') === 0) {
      Image($rawfile('suits/diamond.svg')).width(size).height(size).objectFit(ImageFit.Contain)
    } else {
      Image($rawfile('suits/joker.svg')).width(size).height(size).objectFit(ImageFit.Contain)
    }
  }

  @Builder
  TutorialCard(card: string, index: number) {
    Button() {
      if (this.definition.id === GameId.COLOR_CLASH) {
        Column({ space: 4 }) {
          Text(card.indexOf('万能') === 0 ? '◇' : card.substring(0, 1))
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFF8E8')
          Text(card.indexOf('万能') === 0 ? card.substring(2) : card.substring(1))
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFF8E8')
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor(this.colorCardColor(card))
      } else {
        Stack({ alignContent: Alignment.Center }) {
          Column({ space: 2 }) {
            Text(card === '大王' || card === '小王' ? card : card.substring(1))
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(card.indexOf('♥') === 0 || card.indexOf('♦') === 0 || card === '大王' ? '#C7352C' : '#20241F')
            this.SuitSvg(card, 24)
          }
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#FFFEF8')
      }
    }
    .width(60)
    .height(90)
    .padding(0)
    .margin({ right: -12, top: this.practiceIndex === index ? 0 : 12 })
    .borderRadius(9)
    .border({ width: this.practiceIndex === index ? 3 : 1,
      color: this.practiceIndex === index ? '#FFD55F' : '#DCCDB5' })
    .shadow({ radius: 4, color: '#501A2822', offsetY: 3 })
    .onClick(() => {
      this.selectPractice(index, card);
    })
  }

  @Builder
  CardTableScene() {
    Column() {
      Row() {
        Text('农民 A · 17 张').fontSize(11).fontColor('#E5F0E7')
        Blank()
        Text('农民 B · 17 张').fontSize(11).fontColor('#E5F0E7')
      }
      .width('100%')
      .padding({ left: 24, right: 24 })
      Blank()
      Row({ space: 7 }) {
        Text('上一手').fontSize(10).fontColor('#CDE1D2')
        this.TutorialCard(this.definition.id === GameId.COLOR_CLASH ? '红7' : '♣10', 90)
      }
      Blank()
      Text('你的手牌 · 已按牌力从大到小排列')
        .width('100%')
        .fontSize(11)
        .fontColor('#FFF4D0')
        .padding({ left: 18, bottom: 5 })
      Scroll() {
        Row() {
          ForEach(this.tutorialCards(), (card: string, index: number) => {
            this.TutorialCard(card, index)
          }, (card: string, index: number) => index.toString() + card)
          Blank().width(18)
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
      .height(106)
    }
    .width('100%')
    .height('100%')
    .padding({ top: 14, bottom: 12 })
    .backgroundColor('#236647')
  }

  @Builder
  MahjongTile(tile: string, index: number) {
    Button() {
      Column({ space: 1 }) {
        Text(tile.substring(0, 1))
          .fontSize(23)
          .fontWeight(FontWeight.Bold)
          .fontColor(tile.indexOf('万') > 0 ? '#B63C35' : tile.indexOf('筒') > 0 ? '#2F6097' : '#2E7452')
        Text(tile.substring(1))
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor(tile.indexOf('万') > 0 ? '#B63C35' : tile.indexOf('筒') > 0 ? '#2F6097' : '#2E7452')
      }
    }
    .width(50)
    .height(70)
    .padding(0)
    .margin({ right: -2, top: this.practiceIndex === index ? 0 : 9 })
    .borderRadius(7)
    .border({ width: this.practiceIndex === index ? 3 : 1,
      color: this.practiceIndex === index ? '#FFD45E' : '#D5C59F' })
    .backgroundColor('#FFFCEB')
    .onClick(() => {
      this.selectPractice(index, tile);
    })
  }

  @Builder
  MahjongTableScene() {
    Column() {
      Text('北家 · 13 张').fontSize(11).fontColor('#E2F0E6')
      Blank()
      Row() {
        Text('西家\n13 张').fontSize(10).fontColor('#E2F0E6').textAlign(TextAlign.Center)
        Column({ space: 8 }) {
          Text('东 · 余 55').fontSize(14).fontWeight(FontWeight.Bold).fontColor('#FFE08A')
          Row({ space: 5 }) {
            ForEach(['9万', '7筒', '3条', '2万'], (tile: string, index: number) => {
              Text(tile)
                .width(34)
                .height(44)
                .fontSize(11)
                .fontWeight(FontWeight.Bold)
                .fontColor('#315D4A')
                .textAlign(TextAlign.Center)
                .padding({ top: 14 })
                .borderRadius(4)
                .backgroundColor('#FFFCEB')
            }, (tile: string, index: number) => index.toString() + tile)
          }
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        Text('东家\n13 张').fontSize(10).fontColor('#E2F0E6').textAlign(TextAlign.Center)
      }
      .width('100%')
      Blank()
      Text('你的手牌 · 分门并按点数从大到小排列')
        .width('100%')
        .fontSize(11)
        .fontColor('#FFF4D0')
        .padding({ left: 18, bottom: 5 })
      Scroll() {
        Row() {
          ForEach(this.mahjongTiles(), (tile: string, index: number) => {
            this.MahjongTile(tile, index)
          }, (tile: string, index: number) => index.toString() + tile)
          Blank().width(10)
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
      .height(84)
    }
    .width('100%')
    .height('100%')
    .padding({ top: 12, bottom: 10, left: 10, right: 10 })
    .backgroundColor('#175649')
  }

  @Builder
  BoardTableScene() {
    Row() {
      Grid() {
        ForEach(this.boardIndexes(), (index: number) => {
          GridItem() {
            Stack({ alignContent: Alignment.Center }) {
              if (this.boardSymbol(index).length > 0) {
                Text(this.boardSymbol(index))
                  .fontSize(this.definition.id === GameId.GOMOKU || this.definition.id === GameId.REVERSI ? 16 : 12)
                  .fontWeight(FontWeight.Bold)
                  .fontFamily('serif')
                  .fontColor(index < this.boardIndexes().length / 2 ? '#273C31' : '#A4372E')
              }
            }
            .width('100%')
            .height('100%')
            .border({ width: this.practiceIndex === index ? 2 : 0.6,
              color: this.practiceIndex === index ? '#FFE069' : '#6E5334' })
            .backgroundColor(this.practiceIndex === index ? '#FFE99A88' : '#00000000')
            .onClick(() => {
              this.selectPractice(index, '棋盘位置 ' + (index + 1).toString());
            })
          }
        }, (index: number) => index.toString())
      }
      .columnsTemplate('1fr '.repeat(this.boardColumns()).trim())
      .rowsTemplate('1fr '.repeat(this.boardRows()).trim())
      .height('100%')
      .aspectRatio(this.boardColumns() / this.boardRows())
      .padding(7)
      .borderRadius(10)
      .backgroundColor(this.boardColor())
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .padding(10)
    .backgroundColor('#6D4931')
  }

  @Builder
  PartyTableScene() {
    Column({ space: 12 }) {
      Row() {
        Text('2号').width(48).height(48).fontSize(13).fontWeight(FontWeight.Bold).fontColor('#FFF2D7')
          .textAlign(TextAlign.Center).padding({ top: 15 }).borderRadius(24).backgroundColor('#6D4A38')
        Blank()
        Text('3号').width(48).height(48).fontSize(13).fontWeight(FontWeight.Bold).fontColor('#FFF2D7')
          .textAlign(TextAlign.Center).padding({ top: 15 }).borderRadius(24).backgroundColor('#6D4A38')
      }
      .width('100%')
      Column({ space: 8 }) {
        Text(this.definition.iconText)
          .fontSize(44)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFE0A0')
        Text(this.definition.id === GameId.DRAW_GUESS ? '在真实画板上练习观察与作答' : '当前席位的私密操作区')
          .fontSize(13)
          .fontColor('#FFF4DF')
        Text('点击右侧操作完成本轮演练')
          .fontSize(10)
          .fontColor('#D9C7AA')
      }
      .layoutWeight(1)
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .borderRadius(18)
      .border({ width: 1, color: '#AE8457' })
      .backgroundColor('#2F493C')
      Row() {
        Text('1号 · 当前玩家').fontSize(11).fontColor('#FFF2D7')
        Blank()
        Text('4号').fontSize(11).fontColor('#FFF2D7')
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .padding(18)
    .backgroundColor('#5C3D2D')
  }

  @Builder
  LiveScene() {
    Column() {
      if (this.isCardTeaching()) {
        this.CardTableScene()
      } else if (this.definition.id === GameId.SICHUAN_MAHJONG) {
        this.MahjongTableScene()
      } else if (this.isBoardTeaching()) {
        this.BoardTableScene()
      } else {
        this.PartyTableScene()
      }
    }
    .width('100%')
    .height('100%')
    .padding({ top: 48, right: this.isLandscapeLayout() ? 330 : 0,
      bottom: this.isLandscapeLayout() ? 0 : 294 })
  }

  @Builder
  TutorialHeader() {
    Row({ space: 9 }) {
      Button('退出')
        .height(34)
        .fontSize(10)
        .fontColor('#FFF6E3')
        .backgroundColor('#241A15AA')
        .onClick(() => {
          router.back();
        })
      Text(this.definition.title + ' · 实景教学')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFF8E8')
        .layoutWeight(1)
      Row({ space: 4 }) {
        ForEach(this.progressIndexes(), (index: number) => {
          Blank()
            .width(index === this.stepIndex ? 18 : 6)
            .height(6)
            .borderRadius(3)
            .backgroundColor(index <= this.stepIndex ? '#FFD36B' : '#FFFFFF55')
        }, (index: number) => index.toString())
      }
      Text((this.stepIndex + 1).toString() + '/' + this.steps.length.toString())
        .fontSize(10)
        .fontColor('#F1DFC2')
    }
    .width('100%')
    .height(48)
    .padding({ left: 10, right: 12, top: 6, bottom: 6 })
    .border({ width: { bottom: 1 }, color: '#4DFFFFFF' })
    .backgroundColor('#A618201D')
    .backgroundBlurStyle(BlurStyle.Thin)
  }

  @Builder
  TutorialPanel() {
    Scroll() {
      Column({ space: 9 }) {
        Text('实景演练 · ' + this.currentStep().title)
          .width('100%')
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .fontColor('#302118')
        Text(this.currentStep().explanation)
          .width('100%')
          .fontSize(12)
          .lineHeight(18)
          .fontColor('#664F40')
          .maxLines(this.isLandscapeLayout() ? 3 : 2)
        Text(this.currentStep().question)
          .width('100%')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor('#315D47')
        ForEach(this.currentStep().options, (option: string, index: number) => {
          Button(String.fromCharCode(65 + index) + '  ' + option)
            .width('100%')
            .height(36)
            .fontSize(11)
            .fontColor(this.selectedOption === index ? '#FFF9EB' : '#4A372A')
            .backgroundColor(this.selectedOption === index ?
              (index === this.currentStep().correctIndex ? '#3E7557' : '#A95445') : '#F1E4CF')
            .onClick(() => {
              this.chooseOption(index);
            })
        }, (option: string, index: number) => index.toString() + option)
        Text(this.feedback)
          .width('100%')
          .fontSize(10)
          .fontColor(this.selectedOption === this.currentStep().correctIndex ? '#2E6848' : '#8C533F')
        Row({ space: 8 }) {
          Button('上一步')
            .layoutWeight(1)
            .height(38)
            .enabled(this.stepIndex > 0)
            .fontSize(11)
            .fontColor('#4B372A')
            .backgroundColor('#EADCC8')
            .onClick(() => {
              this.previous();
            })
          Button(this.stepIndex >= this.steps.length - 1 ? '完成' : '下一步')
            .layoutWeight(2)
            .height(38)
            .fontSize(11)
            .backgroundColor('#0A59F7')
            .onClick(() => {
              this.next();
            })
        }
        .width('100%')
      }
      .width('100%')
      .padding(14)
    }
    .scrollBar(BarState.Off)
    .width(this.isLandscapeLayout() ? 330 : '100%')
    .height(this.isLandscapeLayout() ? '100%' : 294)
    .border({ width: 1, color: '#99FFFFFF' })
    .backgroundColor('#D9FFFFFF')
    .backgroundBlurStyle(BlurStyle.Thick)
    .shadow({ radius: 24, color: '#2608172B', offsetX: -6 })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.LiveScene()
      Column() {
        this.TutorialHeader()
        if (this.isLandscapeLayout()) {
          Row() {
            Blank()
            this.TutorialPanel()
          }
          .width('100%')
          .layoutWeight(1)
        } else {
          Blank()
          this.TutorialPanel()
        }
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#243F33')
    .onAreaChange((oldValue: Area, newValue: Area) => {
      this.pageWidth = Number(newValue.width);
      this.pageHeight = Number(newValue.height);
    })
  }
}
