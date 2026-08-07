import { router } from '@kit.ArkUI';
import { ContentPackSummary, ContentSummary } from '../services/ContentLibrary';
import { PartyAppStore } from '../viewmodels/PartyAppStore';

@Entry
@Component
struct ContentLibraryPage {
  @State summaries: ContentSummary[] = [];
  @State message: string = '内容全部保存在本机，导入包只接受纯文本 JSON';
  @State editorVisible: boolean = false;
  @State importText: string = '';
  @State packs: ContentPackSummary[] = [];
  private store: PartyAppStore = PartyAppStore.getInstance();

  aboutToAppear(): void {
    this.summaries = this.store.content().summaries();
    this.packs = this.store.content().packSummaries();
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
        Text('原创内容库')
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .margin({ left: 12 })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 10 })

      Scroll() {
        Column({ space: 11 }) {
          Column({ space: 5 }) {
            Text('开箱即玩')
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFF7E8')
            Text('题库覆盖卧底、画猜、演猜、狼人配置与派对挑战；支持后续导入 ContentPackV1。')
              .fontSize(11)
              .lineHeight(18)
              .fontColor('#ECD9BF')
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(18)
          .borderRadius(22)
          .backgroundColor('#5D3C29')

          ForEach(this.summaries, (summary: ContentSummary) => {
            Row() {
              Column({ space: 4 }) {
                Text(summary.title)
                  .fontSize(15)
                  .fontWeight(FontWeight.Bold)
                Text('内置 ' + summary.builtInCount.toString() + ' · 自定义 ' + summary.customCount.toString())
                  .fontSize(10)
                  .fontColor('#806955')
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              Text('已启用')
                .fontSize(10)
                .fontColor('#397151')
                .padding({ left: 9, right: 9, top: 5, bottom: 5 })
                .borderRadius(10)
                .backgroundColor('#E2EEE3')
            }
            .width('100%')
            .padding(15)
            .borderRadius(17)
            .backgroundColor('#FFFDF8')
          }, (summary: ContentSummary, index: number) => summary.gameId + '-' + index.toString())

          if (this.packs.length > 0) {
            Text('本地内容包')
              .width('100%')
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .margin({ top: 4 })
            ForEach(this.packs, (pack: ContentPackSummary) => {
              Row({ space: 10 }) {
                Column({ space: 3 }) {
                  Text(pack.title)
                    .fontSize(14)
                    .fontWeight(FontWeight.Bold)
                  Text(pack.gameTitle + ' · ' + pack.entryCount.toString() + ' 条')
                    .fontSize(10)
                    .fontColor('#806955')
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                Toggle({ type: ToggleType.Switch, isOn: pack.enabled })
                  .onChange(() => {
                    this.message = this.store.content().togglePack(pack.id);
                    this.packs = this.store.content().packSummaries();
                    this.summaries = this.store.content().summaries();
                    this.store.savePreferences();
                  })
              }
              .width('100%')
              .padding(14)
              .borderRadius(16)
              .backgroundColor('#FFFDF8')
            }, (pack: ContentPackSummary) => pack.id)
          }

          Row({ space: 8 }) {
            Button('本地新增')
              .layoutWeight(1)
              .height(43)
              .fontColor('#4D3323')
              .backgroundColor('#F1E4CF')
              .onClick(() => {
                this.editorVisible = true;
                this.importText = '{"version":1,"id":"my-pack-1","title":"我的题库","gameId":"drawGuess","locale":"zh-CN","entries":["戴草帽的海豚","会唱歌的灯塔"]}';
                this.message = '可直接修改下方 ContentPackV1 模板后导入';
              })
            Button('导入 JSON')
              .layoutWeight(1)
              .height(43)
              .backgroundColor('#6B4330')
              .onClick(() => {
                this.editorVisible = true;
                this.importText = '';
                this.message = '粘贴 ContentPackV1 JSON：版本、游戏类型、字段、大小和重复项都会校验';
              })
          }

          if (this.editorVisible) {
            Column({ space: 9 }) {
              TextArea({ text: this.importText, placeholder: '粘贴 ContentPackV1 JSON' })
                .width('100%')
                .height(150)
                .fontSize(11)
                .backgroundColor('#FFFDF8')
                .borderRadius(13)
                .onChange((value: string) => {
                  this.importText = value;
                })
              Button('校验并导入')
                .width('100%')
                .height(42)
                .backgroundColor('#6B4330')
                .onClick(() => {
                  this.message = this.store.content().importJson(this.importText);
                  this.summaries = this.store.content().summaries();
                  this.packs = this.store.content().packSummaries();
                  this.store.savePreferences();
                })
            }
            .width('100%')
          }

          Text(this.message)
            .width('100%')
            .fontSize(11)
            .lineHeight(18)
            .fontColor('#715743')
            .padding(13)
            .borderRadius(14)
            .backgroundColor('#F1E4CF')
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
