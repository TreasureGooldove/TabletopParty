import { router } from '@kit.ArkUI';
import { GameDefinition, GameId } from '../core/GameContracts';
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
  @State feedback: string = '';
  private store: PartyAppStore = PartyAppStore.getInstance();

  aboutToAppear(): void {
    this.definition = this.store.selectedDefinition();
    this.steps = TutorialCatalog.steps(this.definition.id);
    this.stepIndex = 0;
    this.selectedOption = -1;
    this.feedback = '';
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
    if (index === this.currentStep().correctIndex) {
      this.feedback = '回答正确，可以进入下一步';
    } else {
      this.feedback = '再想一想，也可以回看上面的示例';
    }
  }

  private previous(): void {
    if (this.stepIndex <= 0) {
      return;
    }
    this.stepIndex -= 1;
    this.selectedOption = -1;
    this.feedback = '';
  }

  private next(): void {
    if (this.selectedOption !== this.currentStep().correctIndex) {
      this.feedback = '先完成本步的小练习';
      return;
    }
    if (this.stepIndex >= this.steps.length - 1) {
      router.back();
      return;
    }
    this.stepIndex += 1;
    this.selectedOption = -1;
    this.feedback = '';
  }

  private isCardTeaching(): boolean {
    return this.definition.id === GameId.LANDLORD || this.definition.id === GameId.GUANDAN ||
      this.definition.id === GameId.COLOR_CLASH;
  }

  private isTileTeaching(): boolean {
    return this.definition.id === GameId.SICHUAN_MAHJONG;
  }

  private isBoardTeaching(): boolean {
    return this.definition.id === GameId.CHINESE_CHESS || this.definition.id === GameId.JUNQI ||
      this.definition.id === GameId.GOMOKU || this.definition.id === GameId.REVERSI;
  }

  @Builder
  TeachingDemo() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.isCardTeaching()) {
        Row({ space: -7 }) {
          ForEach(['♠A', '♥K', '♣Q', '♦J'], (card: string, index: number) => {
            Column({ space: 2 }) {
              Text(card.substring(1))
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor(card.indexOf('♥') === 0 || card.indexOf('♦') === 0 ? '#B83A30' : '#282522')
              Text(card.substring(0, 1))
                .fontSize(20)
                .fontColor(card.indexOf('♥') === 0 || card.indexOf('♦') === 0 ? '#B83A30' : '#282522')
            }
            .width(58)
            .height(84)
            .justifyContent(FlexAlign.Center)
            .margin({ top: index % 2 === 0 ? 0 : 10 })
            .borderRadius(9)
            .border({ width: 1, color: '#D9C7AB' })
            .backgroundColor('#FFFDF8')
            .shadow({ radius: 4, color: '#402D211A', offsetY: 3 })
          }, (card: string) => card)
        }
      } else if (this.isTileTeaching()) {
        Row({ space: 7 }) {
          ForEach(['2万', '3万', '4万', '7筒', '7筒'], (tile: string, index: number) => {
            Column({ space: 1 }) {
              Text(tile.substring(0, 1))
                .fontSize(23)
                .fontWeight(FontWeight.Bold)
                .fontColor(tile.indexOf('万') > 0 ? '#B33B32' : '#315E9B')
              Text(tile.substring(1))
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .fontColor(tile.indexOf('万') > 0 ? '#B33B32' : '#315E9B')
            }
            .width(46)
            .height(64)
            .justifyContent(FlexAlign.Center)
            .borderRadius(7)
            .border({ width: 1, color: '#D6C49E' })
            .backgroundColor('#FFFCE9')
          }, (tile: string, index: number) => index.toString() + tile)
        }
      } else if (this.isBoardTeaching()) {
        Row({ space: 14 }) {
          ForEach(this.definition.id === GameId.CHINESE_CHESS ? ['車', '馬', '炮', '帥'] : ['●', '○', '◆', '旗'],
            (piece: string, index: number) => {
              Stack({ alignContent: Alignment.Center }) {
                Text(piece)
                  .fontSize(24)
                  .fontWeight(FontWeight.Bold)
                  .fontFamily('serif')
                  .fontColor(index % 2 === 0 ? '#A6332B' : '#29483A')
              }
              .width(54)
              .height(54)
              .borderRadius(27)
              .border({ width: 2, color: index % 2 === 0 ? '#A6332B' : '#29483A' })
              .backgroundColor('#F8E4B8')
            }, (piece: string, index: number) => index.toString() + piece)
        }
      } else {
        Column({ space: 5 }) {
          Text(this.definition.iconText)
            .fontSize(43)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFF3DD')
          Text('看规则 · 做练习 · 再开局')
            .fontSize(11)
            .fontColor('#EBD9BF')
        }
      }
    }
    .width('100%')
    .height(126)
    .borderRadius(18)
    .backgroundColor('#6B4330')
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
          Text(this.definition.title + ' · 教学模式')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#332319')
          Text('第 ' + (this.stepIndex + 1).toString() + ' / ' + this.steps.length.toString() + ' 步')
            .fontSize(10)
            .fontColor('#7A6250')
        }
        .margin({ left: 12 })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 9 })

      Row({ space: 5 }) {
        ForEach(this.progressIndexes(), (index: number) => {
          Blank()
            .layoutWeight(1)
            .height(5)
            .borderRadius(3)
            .backgroundColor(index <= this.stepIndex ? '#A75A38' : '#E5D8C6')
        }, (index: number) => index.toString())
      }
      .width('100%')
      .padding({ left: 18, right: 18, bottom: 10 })

      Scroll() {
        Column({ space: 14 }) {
          this.TeachingDemo()

          Column({ space: 9 }) {
            Text(this.currentStep().title)
              .width('100%')
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor('#2F2219')
            Text(this.currentStep().explanation)
              .width('100%')
              .fontSize(14)
              .lineHeight(23)
              .fontColor('#675143')
            Text('示例 · ' + this.currentStep().example)
              .width('100%')
              .fontSize(12)
              .lineHeight(20)
              .fontColor('#315D47')
              .padding(12)
              .borderRadius(13)
              .backgroundColor('#E5F0E6')
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(18)
          .borderRadius(20)
          .backgroundColor('#FFFDF8')

          Column({ space: 10 }) {
            Text('马上练一下')
              .width('100%')
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor('#A45A37')
            Text(this.currentStep().question)
              .width('100%')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#332319')
            ForEach(this.currentStep().options, (option: string, index: number) => {
              Button(String.fromCharCode(65 + index) + '  ' + option)
                .width('100%')
                .height(46)
                .fontSize(13)
                .fontColor(this.selectedOption === index ? '#FFF9EB' : '#4A372A')
                .backgroundColor(this.selectedOption === index ?
                  (index === this.currentStep().correctIndex ? '#3E7557' : '#A95445') : '#F1E4CF')
                .onClick(() => {
                  this.chooseOption(index);
                })
            }, (option: string, index: number) => index.toString() + option)
            if (this.feedback.length > 0) {
              Text(this.feedback)
                .width('100%')
                .fontSize(11)
                .fontColor(this.selectedOption === this.currentStep().correctIndex ? '#2E6848' : '#934B3E')
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(18)
          .borderRadius(20)
          .backgroundColor('#FFFDF8')

          Row({ space: 10 }) {
            Button('上一步')
              .layoutWeight(1)
              .height(48)
              .enabled(this.stepIndex > 0)
              .fontColor('#4B372A')
              .backgroundColor('#EADCC8')
              .onClick(() => {
                this.previous();
              })
            Button(this.stepIndex >= this.steps.length - 1 ? '完成教学' : '下一步')
              .layoutWeight(2)
              .height(48)
              .backgroundColor('#6B4330')
              .onClick(() => {
                this.next();
              })
          }
          .width('100%')
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
