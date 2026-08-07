import { router } from '@kit.ArkUI';
import { GameRecord } from '../core/GameContracts';
import { PartyAppStore } from '../viewmodels/PartyAppStore';

@Entry
@Component
struct StatsPage {
  @State records: GameRecord[] = [];
  private store: PartyAppStore = PartyAppStore.getInstance();

  aboutToAppear(): void {
    this.records = this.store.records();
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
        Text('本机战绩')
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .margin({ left: 12 })
      }
      .width('100%')
      .padding(16)

      if (this.records.length === 0) {
        Column({ space: 10 }) {
          Text('棋')
            .fontSize(42)
          Text('还没有完成的对局')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
          Text('完成一局后，这里只保留游戏、人数、结果与时间。')
            .fontSize(11)
            .fontColor('#806955')
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 9 }) {
          ForEach(this.records, (record: GameRecord) => {
            ListItem() {
              Column({ space: 5 }) {
                Row() {
                  Text(record.gameTitle)
                    .fontSize(15)
                    .fontWeight(FontWeight.Bold)
                    .layoutWeight(1)
                  Text(record.playerCount.toString() + ' 人')
                    .fontSize(10)
                    .fontColor('#7B624F')
                }
                Text(record.result)
                  .width('100%')
                  .fontSize(11)
                  .fontColor('#5F493A')
                Text(record.finishedAt)
                  .width('100%')
                  .fontSize(9)
                  .fontColor('#9A806A')
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
              .padding(14)
              .borderRadius(16)
              .backgroundColor('#FFFDF8')
            }
          }, (record: GameRecord) => record.id)
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 16, right: 16, bottom: 20 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FAF4E9')
  }
}
