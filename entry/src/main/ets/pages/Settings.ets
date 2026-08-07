import { router } from '@kit.ArkUI';
import { PartyAppStore } from '../viewmodels/PartyAppStore';

@Entry
@Component
struct SettingsPage {
  @State reduceMotion: boolean = false;
  @State vibration: boolean = true;
  @State largeText: boolean = false;
  @State privateReveal: boolean = true;
  private store: PartyAppStore = PartyAppStore.getInstance();

  aboutToAppear(): void {
    this.reduceMotion = this.store.settings.reduceMotion;
    this.vibration = this.store.settings.vibration;
    this.largeText = this.store.settings.largeText;
    this.privateReveal = this.store.settings.privateReveal;
  }

  private save(): void {
    this.store.settings.reduceMotion = this.reduceMotion;
    this.store.settings.vibration = this.vibration;
    this.store.settings.largeText = this.largeText;
    this.store.settings.privateReveal = this.privateReveal;
    this.store.savePreferences();
  }

  @Builder
  SettingRow(title: string, subtitle: string, value: boolean, action: string) {
    Row() {
      Column({ space: 4 }) {
        Text(title)
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
        Text(subtitle)
          .fontSize(10)
          .fontColor('#806955')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: value })
        .selectedColor('#6B4330')
        .onChange((isOn: boolean) => {
          if (action === 'motion') {
            this.reduceMotion = isOn;
          } else if (action === 'vibration') {
            this.vibration = isOn;
          } else if (action === 'font') {
            this.largeText = isOn;
          } else {
            this.privateReveal = isOn;
          }
          this.save();
        })
    }
    .width('100%')
    .padding(15)
    .borderRadius(16)
    .backgroundColor('#FFFDF8')
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
        Text('设置与无障碍')
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .margin({ left: 12 })
      }
      .width('100%')
      .padding(16)

      Column({ space: 10 }) {
        this.SettingRow('减少动画', '降低转场和棋子移动效果', this.reduceMotion, 'motion')
        this.SettingRow('触感反馈', '落子、投票与轮次切换时振动', this.vibration, 'vibration')
        this.SettingRow('大号文字', '为规则与主持流程使用更大字号', this.largeText, 'font')
        this.SettingRow('私密信息遮罩', '热座时确认后才显示身份或手牌', this.privateReveal, 'private')

        Text('隐私说明')
          .width('100%')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .margin({ top: 8 })
        Text('仅保存昵称、偏好、内容包和简要战绩。房间结束后立即清除身份、手牌、临时密钥和未公开状态，不提供进程退出后的续局。')
          .width('100%')
          .fontSize(11)
          .lineHeight(19)
          .fontColor('#705744')
          .padding(14)
          .borderRadius(15)
          .backgroundColor('#F1E4CF')
      }
      .width('100%')
      .padding({ left: 16, right: 16 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FAF4E9')
  }
}
