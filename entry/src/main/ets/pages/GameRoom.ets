import { router } from '@kit.ArkUI';
import {
  ActionResult,
  GameChoice,
  GameId,
  GameView,
  PlayerKind,
  RoomPhase,
  RoomPlayer
} from '../core/GameContracts';
import { RoomSession } from '../core/RoomEngine';
import { PartyAppStore } from '../viewmodels/PartyAppStore';

@Entry
@Component
struct GameRoom {
  @State view: GameView = new GameView();
  @State players: RoomPlayer[] = [];
  @State currentSeat: number = 0;
  @State message: string = '';
  @State secretVisible: boolean = false;
  @State answer: string = '';
  @State selectedCardIndexes: number[] = [];
  @State pageWidth: number = 360;
  @State pageHeight: number = 800;
  @State landscapeRequested: boolean = false;
  private store: PartyAppStore = PartyAppStore.getInstance();
  private canvasSettings: RenderingContextSettings = new RenderingContextSettings(true);
  private canvasContext: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.canvasSettings);

  aboutToAppear(): void {
    this.refresh();
    this.store.setGameFullscreen(true).catch(() => {
      return;
    });
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

  private refresh(): void {
    const session: RoomSession | null = this.store.session();
    if (session !== null) {
      this.players = session.players.slice();
    }
    this.currentSeat = this.store.currentSeat();
    this.view = this.store.currentView();
    this.message = this.store.message;
  }

  private chooseSeat(index: number): void {
    this.store.selectSeat(index);
    this.secretVisible = false;
    this.selectedCardIndexes = [];
    this.refresh();
  }

  private act(type: string, value: number = -1, first: string = ''): void {
    const result: ActionResult = this.store.act(type, value, first);
    this.message = result.message;
    this.secretVisible = false;
    if (result.success) {
      this.selectedCardIndexes = [];
    }
    this.refresh();
    if (result.success) {
      this.runAiIfNeeded();
    }
  }

  private runAiIfNeeded(): void {
    const session: RoomSession | null = this.store.session();
    if (session === null || this.view.phase === RoomPhase.FINISHED) {
      return;
    }
    for (let guard: number = 0; guard < session.players.length + 4; guard += 1) {
      const result: ActionResult = this.store.runAiTurn();
      if (!result.success) {
        break;
      }
      this.refresh();
    }
  }

  private submitAnswer(): void {
    if (this.answer.trim().length === 0) {
      this.message = '请输入答案或数字';
      return;
    }
    if (this.view.gameId === GameId.NUMBER_BOMB) {
      const value: number = Number(this.answer);
      this.answer = '';
      this.act('guess', value);
    } else {
      const value: string = this.answer.trim();
      this.answer = '';
      this.act('guess', -1, value);
    }
  }

  private isClimbingGame(): boolean {
    return this.view.gameId === GameId.LANDLORD || this.view.gameId === GameId.GUANDAN;
  }

  private isLandscapeLayout(): boolean {
    return this.pageWidth > this.pageHeight;
  }

  private supportsLandscapeTable(): boolean {
    return this.view.gameId === GameId.LANDLORD || this.view.gameId === GameId.SICHUAN_MAHJONG ||
      this.view.gameId === GameId.CHINESE_CHESS;
  }

  private toggleLandscape(): void {
    const next: boolean = !this.landscapeRequested;
    this.store.setGameLandscape(next).then((result: ActionResult) => {
      this.message = result.message;
      if (result.success) {
        this.landscapeRequested = next;
      }
    }).catch(() => {
      this.message = '当前窗口暂不支持切换方向';
    });
  }

  private relativeSeat(offset: number): number {
    if (this.players.length === 0) {
      return 0;
    }
    return (this.currentSeat + offset) % this.players.length;
  }

  private playerName(index: number): string {
    if (index >= 0 && index < this.players.length) {
      return this.players[index].nickname;
    }
    return '等待玩家';
  }

  private playerHandCount(index: number): number {
    if (index >= 0 && index < this.view.handCounts.length) {
      return this.view.handCounts[index];
    }
    return 0;
  }

  private playerMissingSuit(index: number): string {
    if (index >= 0 && index < this.view.missingSuits.length && this.view.missingSuits[index].length > 0) {
      return '缺' + this.view.missingSuits[index];
    }
    return '';
  }

  private playerDiscard(index: number): string[] {
    if (index >= 0 && index < this.view.playerDiscards.length) {
      return this.view.playerDiscards[index];
    }
    return [];
  }

  private previewIndexes(count: number): number[] {
    const result: number[] = [];
    const total: number = Math.min(5, Math.max(0, count));
    for (let index: number = 0; index < total; index += 1) {
      result.push(index);
    }
    return result;
  }

  private playerInitial(index: number): string {
    const name: string = this.playerName(index);
    return name.length > 0 ? name.substring(0, 1) : '玩';
  }

  private mahjongTableChoices(): GameChoice[] {
    const result: GameChoice[] = [];
    for (let index: number = 0; index < this.view.choices.length; index += 1) {
      if (this.view.choices[index].actionType !== 'play') {
        result.push(this.view.choices[index]);
      }
    }
    return result;
  }

  private cardRank(card: string): string {
    if (card === '小王' || card === '大王') {
      return card;
    }
    return card.length > 1 ? card.substring(1) : card;
  }

  private cardSuit(card: string): string {
    if (card === '小王' || card === '大王') {
      return '★';
    }
    return card.length > 0 ? card.substring(0, 1) : '';
  }

  private cardTextColor(card: string): string {
    return card.indexOf('♥') === 0 || card.indexOf('♦') === 0 || card === '大王' ? '#C7352C' : '#20241F';
  }

  private suggestLandlordCards(): void {
    if (this.view.hand.length === 0) {
      return;
    }
    let suggestion: number = 0;
    if (this.view.tableCards.length === 1) {
      const targetRank: string = this.cardRank(this.view.tableCards[0]);
      const ranks: string[] = ['3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A', '2', '小王', '大王'];
      const targetValue: number = ranks.indexOf(targetRank);
      for (let index: number = 0; index < this.view.hand.length; index += 1) {
        if (ranks.indexOf(this.cardRank(this.view.hand[index])) > targetValue) {
          suggestion = index;
          break;
        }
      }
    }
    this.selectedCardIndexes = [suggestion];
    this.message = '已选中建议牌，可继续调整后出牌';
  }

  private chessLandscapeBoardWidth(): number {
    return Math.max(250, Math.min(this.pageWidth * 0.6, (this.pageHeight - 58) * 0.89));
  }

  private isMultiSelectGame(): boolean {
    return this.isClimbingGame() || this.view.gameId === GameId.SICHUAN_MAHJONG &&
      this.view.phase === RoomPhase.REVEAL && this.view.prompt.indexOf('三张') >= 0;
  }

  private toggleCard(index: number): void {
    const next: number[] = this.selectedCardIndexes.slice();
    const position: number = next.indexOf(index);
    if (position >= 0) {
      next.splice(position, 1);
    } else {
      next.push(index);
    }
    this.selectedCardIndexes = next;
  }

  private playSelectedCards(): void {
    if (this.selectedCardIndexes.length === 0) {
      this.message = '请先选择要出的牌';
      return;
    }
    const values: string[] = [];
    for (let index: number = 0; index < this.selectedCardIndexes.length; index += 1) {
      values.push(this.selectedCardIndexes[index].toString());
    }
    this.act(this.view.gameId === GameId.SICHUAN_MAHJONG ? 'exchange' : 'play', -1, values.join(','));
  }

  private leaveRoom(): void {
    this.store.endRoom();
    router.clear();
    router.replaceUrl({ url: 'pages/Index' });
  }

  private canDraw(): boolean {
    return this.players.length > this.currentSeat &&
      this.players[this.currentSeat].id === this.view.currentPlayerId;
  }

  private boardOwner(index: number): string {
    if (index >= 0 && index < this.view.boardOwners.length) {
      return this.view.boardOwners[index];
    }
    return '';
  }

  private isJunqiCamp(index: number): boolean {
    const camps: number[] = [11, 13, 17, 21, 23, 36, 38, 42, 46, 48];
    return camps.indexOf(index) >= 0;
  }

  private isJunqiHeadquarters(index: number): boolean {
    return index === 1 || index === 3 || index === 56 || index === 58;
  }

  private isJunqiRail(index: number): boolean {
    const row: number = Math.floor(index / 5);
    const column: number = index % 5;
    return row === 1 || row === 5 || row === 6 || row === 10 ||
      (column === 0 || column === 4) && row >= 1 && row <= 10 ||
      column === 2 && (row >= 1 && row <= 5 || row >= 6 && row <= 10);
  }

  private junqiDisplayName(piece: string): string {
    if (piece === '司') {
      return '司令';
    }
    if (piece === '军') {
      return '军长';
    }
    if (piece === '师') {
      return '师长';
    }
    if (piece === '旅') {
      return '旅长';
    }
    if (piece === '团') {
      return '团长';
    }
    if (piece === '营') {
      return '营长';
    }
    if (piece === '连') {
      return '连长';
    }
    if (piece === '排') {
      return '排长';
    }
    if (piece === '工') {
      return '工兵';
    }
    if (piece === '炸') {
      return '炸弹';
    }
    if (piece === '雷') {
      return '地雷';
    }
    if (piece === '旗') {
      return '军旗';
    }
    return piece;
  }

  private junqiPieceHint(piece: string): string {
    if (piece === '工') {
      return '铁路转弯';
    }
    if (piece === '炸') {
      return '同归于尽';
    }
    if (piece === '雷') {
      return '防守';
    }
    if (piece === '旗') {
      return '目标';
    }
    if (piece === '司' || piece === '军') {
      return '统帅';
    }
    return '军阶';
  }

  private boardAspectRatio(): number {
    if (this.view.gameId === GameId.CHINESE_CHESS) {
      return 0.89;
    }
    if (this.view.gameId === GameId.JUNQI) {
      return 0.48;
    }
    if (this.view.gameId === GameId.LUDO) {
      return 1.35;
    }
    return 1;
  }

  private colorCardBackground(card: string): string {
    if (card.indexOf('红') === 0) {
      return '#C84B42';
    }
    if (card.indexOf('黄') === 0) {
      return '#E5AD3D';
    }
    if (card.indexOf('蓝') === 0) {
      return '#397BB6';
    }
    if (card.indexOf('绿') === 0) {
      return '#4F9765';
    }
    return '#493463';
  }

  private colorCardLabel(card: string): string {
    if (card.indexOf('万能') === 0) {
      return card.substring(2);
    }
    return card.substring(1);
  }

  private mahjongSuitColor(card: string): string {
    if (card.indexOf('万') >= 0) {
      return '#B33B32';
    }
    if (card.indexOf('筒') >= 0) {
      return '#315E9B';
    }
    return '#34704A';
  }

  private ludoCellColor(index: number): string {
    const palette: string[] = ['#E55A52', '#E6B944', '#4B8FD0', '#54A36B'];
    if (index < 10) {
      return palette[0];
    }
    if (index < 25) {
      return palette[1];
    }
    if (index < 40) {
      return palette[2];
    }
    return palette[3];
  }

  private handleDrawTouch(event: TouchEvent): void {
    if (!this.canDraw() || event.touches.length === 0) {
      return;
    }
    const point: TouchObject = event.touches[0];
    if (event.type === TouchType.Down) {
      this.canvasContext.beginPath();
      this.canvasContext.moveTo(point.x, point.y);
    } else if (event.type === TouchType.Move) {
      this.canvasContext.lineTo(point.x, point.y);
      this.canvasContext.stroke();
    } else if (event.type === TouchType.Up) {
      this.act('stroke');
    }
  }

  private clearCanvas(): void {
    this.canvasContext.clearRect(0, 0, 1000, 1000);
  }

  @Builder
  SeatChip(player: RoomPlayer, index: number) {
    Button(player.nickname)
      .height(34)
      .fontSize(11)
      .fontColor(this.currentSeat === index ? '#FFF8EA' : '#5C4434')
      .backgroundColor(this.currentSeat === index ? '#6B4330' : '#F1E4CF')
      .onClick(() => {
        this.chooseSeat(index);
      })
  }

  @Builder
  JunqiCell(cell: string, index: number) {
    GridItem() {
      Stack({ alignContent: Alignment.Center }) {
        if (this.isJunqiRail(index)) {
          Text(index % 5 === 0 || index % 5 === 4 || index % 5 === 2 ? '┃' : '━')
            .fontSize(25)
            .fontColor('#9C8056')
        }
        if (cell.length === 0 && this.isJunqiCamp(index)) {
          Text('行营')
            .fontSize(8)
            .fontColor('#61704B')
        } else if (cell.length === 0 && this.isJunqiHeadquarters(index)) {
          Text('大本营')
            .fontSize(7)
            .fontColor('#83513C')
        }
        if (cell.length > 0) {
          Column({ space: 1 }) {
            Text(this.junqiDisplayName(cell))
              .fontSize(cell === '◆' ? 17 : 12)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFF9EA')
            if (cell !== '◆') {
              Text(this.junqiPieceHint(cell))
                .fontSize(6)
                .fontColor('#EEDFC9')
            }
          }
          .width('88%')
          .height('72%')
          .justifyContent(FlexAlign.Center)
          .borderRadius(6)
          .border({
            width: this.view.selectedBoardIndex === index ? 3 : 1,
            color: this.view.selectedBoardIndex === index ? '#F4CE68' : '#E7D8BD'
          })
          .backgroundColor(this.boardOwner(index) === 'R' ? '#A83D35' : '#315A7D')
          .shadow({ radius: 3, color: '#50322120', offsetY: 2 })
        }
      }
      .width('100%')
      .height('100%')
      .border({ width: 0.5, color: '#BCA47C' })
      .borderRadius(this.isJunqiCamp(index) ? 11 : 2)
      .backgroundColor(this.isJunqiCamp(index) ? '#D9DFB8' :
        (this.isJunqiHeadquarters(index) ? '#E8C8AE' : '#F1E1BD'))
      .onClick(() => {
        this.act('place', index);
      })
    }
  }

  @Builder
  ChineseChessCell(cell: string, index: number) {
    GridItem() {
      Stack({ alignContent: Alignment.Center }) {
        Row() {
          Blank()
            .width('50%')
            .height(1)
            .backgroundColor(index % 9 === 0 ? '#00000000' : '#95602F')
          Blank()
            .width('50%')
            .height(1)
            .backgroundColor(index % 9 === 8 ? '#00000000' : '#95602F')
        }
        .width('100%')
        .height('100%')
        .alignItems(VerticalAlign.Center)
        Column() {
          Blank()
            .width(1)
            .height('50%')
            .backgroundColor(Math.floor(index / 9) === 0 ||
              Math.floor(index / 9) === 5 && index % 9 > 0 && index % 9 < 8 ? '#00000000' : '#95602F')
          Blank()
            .width(1)
            .height('50%')
            .backgroundColor(Math.floor(index / 9) === 9 ||
              Math.floor(index / 9) === 4 && index % 9 > 0 && index % 9 < 8 ? '#00000000' : '#95602F')
        }
        .width('100%')
        .height('100%')
        .alignItems(HorizontalAlign.Center)
        if (cell.length === 0 && Math.floor(index / 9) === 4 && (index % 9 === 2 || index % 9 === 6)) {
          Text(index % 9 === 2 ? '楚 河' : '汉 界')
            .fontSize(9)
            .fontWeight(FontWeight.Bold)
            .fontColor('#80532E')
            .backgroundColor('#EED4A4')
        }
        if (cell.length > 0) {
          Stack({ alignContent: Alignment.Center }) {
            Text(cell)
              .fontSize(this.isLandscapeLayout() ? 20 : 18)
              .fontWeight(FontWeight.Bold)
              .fontFamily('serif')
              .fontColor(this.boardOwner(index) === 'R' ? '#B12E27' : '#263D32')
              .textAlign(TextAlign.Center)
          }
            .width('76%')
            .aspectRatio(1)
            .borderRadius(40)
            .border({
              width: this.view.selectedBoardIndex === index ? 3 : 2,
              color: this.view.selectedBoardIndex === index ? '#E6AF3F' :
                (this.boardOwner(index) === 'R' ? '#AF332B' : '#385648')
            })
            .backgroundColor('#FFF2D2')
            .shadow({ radius: 4, color: '#503B241D', offsetY: 2 })
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#E8C98D')
      .onClick(() => {
        this.act('place', index);
      })
    }
  }

  @Builder
  StoneBoardCell(cell: string, index: number) {
    GridItem() {
      Stack({ alignContent: Alignment.Center }) {
        Text('┼')
          .fontSize(this.view.gameId === GameId.GOMOKU ? 15 : 22)
          .fontColor(this.view.gameId === GameId.REVERSI ? '#183E2A' : '#8B673C')
        if (cell.length > 0) {
          Text('')
            .width(this.view.gameId === GameId.GOMOKU ? '68%' : '76%')
            .aspectRatio(1)
            .borderRadius(99)
            .border({ width: cell === '○' ? 1 : 0, color: '#8F8779' })
            .backgroundColor(cell === '●' ? '#25231F' : '#FAF7EC')
            .shadow({ radius: 3, color: '#5031251E', offsetY: 2 })
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.view.gameId === GameId.REVERSI ? '#4F8B5D' : '#E7C98B')
      .onClick(() => {
        this.act('place', index);
      })
    }
  }

  @Builder
  LudoCell(cell: string, index: number) {
    GridItem() {
      Text(cell.length > 0 ? cell : '')
        .width('100%')
        .height('100%')
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(cell.length > 0 ? '#FFFDF7' : '#765B48')
        .textAlign(TextAlign.Center)
        .padding({ top: 6 })
        .border({ width: 1, color: '#FFF8E6' })
        .borderRadius(6)
        .backgroundColor(this.ludoCellColor(index))
    }
  }

  @Builder
  GenericBoardCell(cell: string, index: number) {
    GridItem() {
      Text(cell.length > 0 ? cell : '·')
        .width('100%')
        .height('100%')
        .fontSize(16)
        .fontWeight(cell.length > 0 ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(cell.length > 0 ? '#3F2B20' : '#B99E7B')
        .textAlign(TextAlign.Center)
        .backgroundColor('#EED7AB')
        .onClick(() => {
          this.act('place', index);
        })
    }
  }

  @Builder
  GameBoardCell(cell: string, index: number) {
    if (this.view.gameId === GameId.JUNQI) {
      this.JunqiCell(cell, index)
    } else if (this.view.gameId === GameId.CHINESE_CHESS) {
      this.ChineseChessCell(cell, index)
    } else if (this.view.gameId === GameId.GOMOKU || this.view.gameId === GameId.REVERSI) {
      this.StoneBoardCell(cell, index)
    } else if (this.view.gameId === GameId.LUDO) {
      this.LudoCell(cell, index)
    } else {
      this.GenericBoardCell(cell, index)
    }
  }

  @Builder
  GameTypeIcon() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.view.gameId === GameId.CHINESE_CHESS || this.view.gameId === GameId.JUNQI ||
        this.view.gameId === GameId.GOMOKU || this.view.gameId === GameId.REVERSI) {
        Image($r('app.media.tabler_chess'))
          .width(25)
          .height(25)
      } else if (this.view.gameId === GameId.LANDLORD || this.view.gameId === GameId.GUANDAN ||
        this.view.gameId === GameId.COLOR_CLASH || this.view.gameId === GameId.SICHUAN_MAHJONG) {
        Image($r('app.media.tabler_cards'))
          .width(25)
          .height(25)
      } else if (this.view.gameId === GameId.LUDO || this.view.gameId === GameId.NUMBER_BOMB) {
        Image($r('app.media.tabler_dice'))
          .width(25)
          .height(25)
      } else {
        Image($r('app.media.tabler_shield'))
          .width(25)
          .height(25)
      }
    }
    .width(42)
    .height(42)
    .margin({ left: 9 })
    .borderRadius(14)
    .backgroundColor('#6B4330')
  }

  @Builder
  CardFace(card: string, index: number) {
    if (this.view.gameId === GameId.COLOR_CLASH) {
      Button() {
        Stack({ alignContent: Alignment.Center }) {
          Text('◇')
            .fontSize(47)
            .fontColor('#66FFFFFF')
            .rotate({ angle: -18 })
          Text(this.colorCardLabel(card))
            .fontSize(card.indexOf('+') >= 0 ? 18 : 22)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
          Text(card.substring(0, 1))
            .fontSize(8)
            .fontColor('#FCEEDF')
            .position({ x: 7, y: 5 })
        }
        .width('100%')
        .height('100%')
      }
      .width(64)
      .height(92)
      .padding(0)
      .margin({ right: 7, bottom: 9, top: this.selectedCardIndexes.indexOf(index) >= 0 ? 0 : 7 })
      .borderRadius(12)
      .border({ width: this.selectedCardIndexes.indexOf(index) >= 0 ? 3 : 2, color: '#FFF7E8' })
      .backgroundColor(this.colorCardBackground(card))
      .shadow({ radius: 6, color: '#40332122', offsetY: 3 })
      .onClick(() => {
        if (this.isMultiSelectGame()) {
          this.toggleCard(index);
        } else {
          this.act('play', index, '红');
        }
      })
    } else if (this.view.gameId === GameId.SICHUAN_MAHJONG) {
      Button() {
        Column({ space: 1 }) {
          Text(card.substring(0, 1))
            .fontSize(23)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.mahjongSuitColor(card))
          Text(card.substring(1))
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.mahjongSuitColor(card))
        }
        .justifyContent(FlexAlign.Center)
      }
      .width(48)
      .height(68)
      .padding(0)
      .margin({ right: 5, bottom: 7, top: this.selectedCardIndexes.indexOf(index) >= 0 ? 0 : 6 })
      .borderRadius(7)
      .border({ width: this.selectedCardIndexes.indexOf(index) >= 0 ? 3 : 1, color: '#D7BE8C' })
      .backgroundColor('#FFFBEA')
      .shadow({ radius: 4, color: '#40332122', offsetY: 3 })
      .onClick(() => {
        if (this.isMultiSelectGame()) {
          this.toggleCard(index);
        } else {
          this.act('play', index, '红');
        }
      })
    } else {
      Button() {
        Column({ space: 2 }) {
          Text(this.cardRank(card))
            .fontSize(card.length > 2 ? 13 : 18)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.cardTextColor(card))
          this.SuitSvg(card, 24)
          Text('桌游派对')
            .fontSize(6)
            .fontColor('#A28B72')
        }
        .justifyContent(FlexAlign.Center)
      }
      .width(60)
      .height(84)
      .padding(0)
      .margin({ right: 6, bottom: 8, top: this.selectedCardIndexes.indexOf(index) >= 0 ? 0 : 6 })
      .borderRadius(10)
      .border({ width: this.selectedCardIndexes.indexOf(index) >= 0 ? 3 : 1, color: '#D7C4AA' })
      .backgroundColor('#FFFDF8')
      .shadow({ radius: 4, color: '#40332122', offsetY: 3 })
      .onClick(() => {
        if (this.isMultiSelectGame()) {
          this.toggleCard(index);
        } else {
          this.act('play', index, '红');
        }
      })
    }
  }

  @Builder
  ChoiceButton(choice: GameChoice) {
    Button(choice.label)
      .height(40)
      .fontSize(11)
      .fontColor('#4B3426')
      .backgroundColor('#F1E4CF')
      .margin({ right: 6, bottom: 6 })
      .onClick(() => {
        this.act(choice.actionType, choice.value, choice.first.length > 0 ? choice.first :
          (choice.actionType === 'play' ? '红' : ''));
      })
  }

  @Builder
  PrivatePanel() {
    Column({ space: 9 }) {
      Row() {
        Text('仅当前席位可见')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
        Button(this.secretVisible ? '遮住' : '确认后查看')
          .height(34)
          .fontSize(10)
          .fontColor('#4D3323')
          .backgroundColor('#F1E4CF')
          .onClick(() => {
            this.secretVisible = !this.secretVisible;
          })
      }
      Text(this.secretVisible ? this.view.privateText : '请把设备交给 ' +
        (this.players.length > this.currentSeat ? this.players[this.currentSeat].nickname : '当前玩家'))
        .width('100%')
        .fontSize(this.secretVisible ? 18 : 13)
        .fontWeight(this.secretVisible ? FontWeight.Bold : FontWeight.Normal)
        .fontColor('#5C3526')
        .textAlign(TextAlign.Center)
        .padding(18)
        .borderRadius(14)
        .backgroundColor('#FFF6E4')
    }
    .width('100%')
    .padding(15)
    .borderRadius(18)
    .backgroundColor('#FFFDF8')
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
  PlayingCard(card: string, compact: boolean = false) {
    if (card.length === 0) {
      Stack({ alignContent: Alignment.Center }) {
        Text('◇')
          .fontSize(compact ? 20 : 26)
          .fontColor('#A9C8DB')
        Text('派')
          .fontSize(8)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F1F7FA')
      }
      .width(compact ? (this.isLandscapeLayout() ? 26 : 32) : 42)
      .height(compact ? (this.isLandscapeLayout() ? 36 : 44) : 58)
      .borderRadius(compact ? 5 : 7)
      .border({ width: 1, color: '#DBEAF0' })
      .backgroundColor('#315F79')
    } else {
      Stack({ alignContent: Alignment.Center }) {
        Column({ space: 0 }) {
          Text(this.cardRank(card))
            .fontSize(compact ? 10 : 13)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.cardTextColor(card))
          this.SuitSvg(card, compact ? 11 : 16)
        }
        .alignItems(HorizontalAlign.Start)
        .position({ x: 4, y: 3 })
      }
      .width(compact ? (this.isLandscapeLayout() ? 26 : 32) : 42)
      .height(compact ? (this.isLandscapeLayout() ? 36 : 44) : 58)
      .borderRadius(compact ? 5 : 7)
      .border({ width: 1, color: '#E3D7C4' })
      .backgroundColor('#FFFEF8')
      .shadow({ radius: 3, color: '#4A20372A', offsetY: 2 })
    }
  }

  @Builder
  LandlordSeat(seat: number, side: string) {
    Column({ space: 5 }) {
      Stack({ alignContent: Alignment.Center }) {
        Text(this.playerInitial(seat))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFF8DF')
        if (this.view.landlordSeat === seat) {
          Text('地主')
            .fontSize(7)
            .fontColor('#5D321A')
            .padding({ left: 5, right: 5, top: 2, bottom: 2 })
            .borderRadius(8)
            .backgroundColor('#F8CC64')
            .position({ x: 34, y: 0 })
        }
      }
      .width(this.isLandscapeLayout() ? 38 : 48)
      .height(this.isLandscapeLayout() ? 38 : 48)
      .borderRadius(24)
      .border({ width: this.view.currentPlayerId === this.players[seat].id ? 2 : 1,
        color: this.view.currentPlayerId === this.players[seat].id ? '#FFD86D' : '#8DB8A0' })
      .backgroundColor(side === 'left' ? '#447C8F' : '#8C6146')
      Text(this.playerName(seat))
        .fontSize(10)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFF8E6')
        .maxLines(1)
      Row() {
        ForEach(this.previewIndexes(this.playerHandCount(seat)), (value: number) => {
          Stack() {
          }
          .width(13)
          .height(22)
          .margin({ right: -6 })
          .borderRadius(2)
          .border({ width: 1, color: '#D9E7EC' })
          .backgroundColor('#315F79')
        }, (value: number) => value.toString())
      }
      Text(this.playerHandCount(seat).toString() + ' 张')
        .fontSize(9)
        .fontColor('#D7E8DC')
    }
    .width(this.isLandscapeLayout() ? 72 : 76)
  }

  @Builder
  LandlordHandCard(card: string, index: number) {
    Button() {
      Stack({ alignContent: Alignment.Center }) {
        Column({ space: 0 }) {
          Text(this.cardRank(card))
            .fontSize(this.isLandscapeLayout() ? 13 : 15)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.cardTextColor(card))
          this.SuitSvg(card, this.isLandscapeLayout() ? 18 : 21)
        }
        .alignItems(HorizontalAlign.Start)
        .position({ x: 5, y: 4 })
      }
      .width('100%')
      .height('100%')
    }
    .width(this.isLandscapeLayout() ? 40 : 52)
    .height(this.isLandscapeLayout() ? 58 : 78)
    .padding(0)
    .margin({ right: -11, top: this.selectedCardIndexes.indexOf(index) >= 0 ? 0 : 11 })
    .borderRadius(7)
    .border({ width: this.selectedCardIndexes.indexOf(index) >= 0 ? 3 : 1,
      color: this.selectedCardIndexes.indexOf(index) >= 0 ? '#FFCF57' : '#E1D5C1' })
    .backgroundColor('#FFFEF8')
    .shadow({ radius: 4, color: '#60243229', offsetY: 3 })
    .onClick(() => {
      this.toggleCard(index);
    })
  }

  @Builder
  LandlordTable() {
    Column({ space: this.isLandscapeLayout() ? 3 : 10 }) {
      Row({ space: 8 }) {
        Text('底牌')
          .fontSize(10)
          .fontColor('#D6E8D9')
        ForEach(this.view.bottomCards, (card: string, index: number) => {
          this.PlayingCard(card, true)
        }, (card: string, index: number) => index.toString() + card)
        Blank()
        Text('倍数 ×' + this.view.multiplier.toString())
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFE18A')
          .padding({ left: 9, right: 9, top: 5, bottom: 5 })
          .borderRadius(12)
          .backgroundColor('#5B3E2588')
      }
      .width('100%')
      .padding({ left: 8, right: 8 })

      Row() {
        this.LandlordSeat(this.relativeSeat(1), 'left')
        Column({ space: 7 }) {
          Text(this.view.tableCards.length > 0 ? '上一手' : '等待领出')
            .fontSize(10)
            .fontColor('#CDE0D2')
          Row({ space: 4 }) {
            ForEach(this.view.tableCards, (card: string, index: number) => {
              this.PlayingCard(card, false)
            }, (card: string, index: number) => index.toString() + card)
          }
          .justifyContent(FlexAlign.Center)
          Text(this.view.status)
            .fontSize(11)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFF4D0')
            .textAlign(TextAlign.Center)
            .maxLines(2)
        }
        .height(this.isLandscapeLayout() ? 74 : 135)
        .justifyContent(FlexAlign.Center)
        .layoutWeight(1)
        this.LandlordSeat(this.relativeSeat(2), 'right')
      }
      .width('100%')

      Row({ space: 7 }) {
        Stack({ alignContent: Alignment.Center }) {
          Text(this.playerInitial(this.currentSeat))
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFF8DF')
        }
        .width(this.isLandscapeLayout() ? 30 : 38)
        .height(this.isLandscapeLayout() ? 30 : 38)
        .borderRadius(19)
        .backgroundColor('#5E4636')
        Column({ space: 1 }) {
          Text(this.playerName(this.currentSeat) + (this.view.landlordSeat === this.currentSeat ? ' · 地主' : ' · 农民'))
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFF8E6')
          Text('手牌 ' + this.view.hand.length.toString() + ' 张')
            .fontSize(8)
            .fontColor('#C9DDD0')
        }
      }
      .width('100%')

      Scroll() {
        Row() {
          ForEach(this.view.hand, (card: string, index: number) => {
            this.LandlordHandCard(card, index)
          }, (card: string, index: number) => index.toString() + card)
          Blank().width(18)
        }
        .padding({ left: 2, right: 2 })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
      .height(this.isLandscapeLayout() ? 64 : 94)

      if (this.view.phase === RoomPhase.REVEAL) {
        Row({ space: 8 }) {
          ForEach(this.view.choices, (choice: GameChoice) => {
            Button(choice.label)
              .height(this.isLandscapeLayout() ? 34 : 38)
              .fontSize(11)
              .fontColor('#49331F')
              .backgroundColor(choice.value === 3 ? '#FFD36D' : '#F5EAD2')
              .onClick(() => {
                this.act(choice.actionType, choice.value, choice.first);
              })
          }, (choice: GameChoice) => choice.id)
        }
        .justifyContent(FlexAlign.Center)
      } else if (this.view.phase !== RoomPhase.FINISHED) {
        Row({ space: 10 }) {
          Button('不出')
            .layoutWeight(1)
            .height(this.isLandscapeLayout() ? 34 : 40)
            .fontColor('#483829')
            .backgroundColor('#F5EAD2')
            .onClick(() => {
              this.act('pass');
            })
          Button('提示')
            .layoutWeight(1)
            .height(this.isLandscapeLayout() ? 34 : 40)
            .fontColor('#483829')
            .backgroundColor('#F8D98B')
            .onClick(() => {
              this.suggestLandlordCards();
            })
          Button('出牌 ' + this.selectedCardIndexes.length.toString())
            .layoutWeight(1)
            .height(this.isLandscapeLayout() ? 34 : 40)
            .backgroundColor('#C96337')
            .onClick(() => {
              this.playSelectedCards();
            })
        }
        .width('100%')
      }
    }
    .width('100%')
    .padding(this.isLandscapeLayout() ? 6 : 14)
    .borderRadius(20)
    .border({ width: 2, color: '#D2AE62' })
    .backgroundColor('#246747')
    .layoutWeight(1)
    .justifyContent(FlexAlign.SpaceBetween)
  }

  @Builder
  MahjongTile(tile: string, compact: boolean = false) {
    Column({ space: 0 }) {
      Text(tile.substring(0, 1))
        .fontSize(compact ? 11 : 17)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.mahjongSuitColor(tile))
      Text(tile.substring(1))
        .fontSize(compact ? 7 : 10)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.mahjongSuitColor(tile))
    }
    .width(compact ? 25 : 38)
    .height(compact ? 34 : 52)
    .justifyContent(FlexAlign.Center)
    .borderRadius(compact ? 4 : 6)
    .border({ width: 1, color: '#D6C8A8' })
    .backgroundColor('#FFFCE9')
    .shadow({ radius: 2, color: '#402D4935', offsetY: 2 })
  }

  @Builder
  MahjongSeat(seat: number) {
    Column({ space: 3 }) {
      Stack({ alignContent: Alignment.Center }) {
        Text(this.playerInitial(seat))
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFF5D8')
      }
      .width(42)
      .height(42)
      .borderRadius(21)
      .border({ width: this.view.currentPlayerId === this.players[seat].id ? 2 : 1,
        color: this.view.currentPlayerId === this.players[seat].id ? '#FFDF76' : '#6FAE9B' })
      .backgroundColor('#34665B')
      Text(this.playerName(seat))
        .fontSize(9)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFF6DB')
        .maxLines(1)
      Text(this.playerHandCount(seat).toString() + ' 张 ' + this.playerMissingSuit(seat))
        .fontSize(8)
        .fontColor('#C9E2D7')
    }
    .width(this.isLandscapeLayout() ? 78 : 62)
  }

  @Builder
  MahjongDiscardArea(seat: number) {
    Column({ space: 2 }) {
      Text(this.playerName(seat))
        .fontSize(7)
        .fontColor('#CAE0D4')
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.playerDiscard(seat).slice(Math.max(0, this.playerDiscard(seat).length - 12)),
          (tile: string, index: number) => {
            this.MahjongTile(tile, true)
          }, (tile: string, index: number) => index.toString() + tile)
      }
      .width('100%')
    }
    .width('48%')
    .height(this.isLandscapeLayout() ? 72 : 82)
    .padding(4)
    .borderRadius(8)
    .backgroundColor('#1E5D5099')
  }

  @Builder
  MahjongHandTile(tile: string, index: number) {
    Button() {
      this.MahjongTile(tile, false)
    }
    .width(40)
    .height(62)
    .padding(0)
    .margin({ right: -2, top: this.selectedCardIndexes.indexOf(index) >= 0 ? 0 : 8 })
    .backgroundColor('#00000000')
    .onClick(() => {
      if (this.isMultiSelectGame()) {
        this.toggleCard(index);
      } else {
        this.act('play', index, '红');
      }
    })
  }

  @Builder
  MahjongTable() {
    Column({ space: this.isLandscapeLayout() ? 5 : 9 }) {
      this.MahjongSeat(this.relativeSeat(2))
      Row() {
        this.MahjongSeat(this.relativeSeat(1))
        Column({ space: 5 }) {
          Row() {
            Text('东')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFE38D')
            Text('余 ' + this.view.remainingCards.toString())
              .fontSize(10)
              .fontColor('#D9EBE2')
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)
          Row() {
            this.MahjongDiscardArea(this.relativeSeat(2))
            this.MahjongDiscardArea(this.relativeSeat(3))
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)
          Row() {
            this.MahjongDiscardArea(this.relativeSeat(1))
            this.MahjongDiscardArea(this.currentSeat)
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)
        }
        .layoutWeight(1)
        .padding(7)
        .borderRadius(15)
        .border({ width: 1, color: '#7DB29B' })
        .backgroundColor('#246B5A')
        this.MahjongSeat(this.relativeSeat(3))
      }
      .width('100%')

      Row({ space: 6 }) {
        Text(this.playerName(this.currentSeat))
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFF6D9')
        Text(this.playerMissingSuit(this.currentSeat))
          .fontSize(9)
          .fontColor('#FFE082')
        Blank()
        Text(this.view.gameStage === 'exchange' ? '换三张' :
          (this.view.gameStage === 'missing' ? '定缺' : '出牌'))
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFF6D9')
      }
      .width('100%')

      Scroll() {
        Row() {
          ForEach(this.view.hand, (tile: string, index: number) => {
            this.MahjongHandTile(tile, index)
          }, (tile: string, index: number) => index.toString() + tile)
          Blank().width(8)
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
      .height(72)

      if (this.view.gameStage === 'exchange') {
        Row({ space: 10 }) {
          Button('重选')
            .layoutWeight(1)
            .height(40)
            .fontColor('#493928')
            .backgroundColor('#F3E8D1')
            .onClick(() => {
              this.selectedCardIndexes = [];
            })
          Button('确认换三张 · ' + this.selectedCardIndexes.length.toString())
            .layoutWeight(2)
            .height(40)
            .backgroundColor('#C66136')
            .onClick(() => {
              this.playSelectedCards();
            })
        }
        .width('100%')
      } else if (this.mahjongTableChoices().length > 0) {
        Row({ space: 8 }) {
          ForEach(this.mahjongTableChoices(), (choice: GameChoice) => {
            Button(choice.label)
              .height(40)
              .fontSize(11)
              .fontColor('#493928')
              .backgroundColor(choice.actionType === 'win' ? '#FFD36A' : '#F3E8D1')
              .onClick(() => {
                this.act(choice.actionType, choice.value, choice.first);
              })
          }, (choice: GameChoice) => choice.id)
        }
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .padding(this.isLandscapeLayout() ? 9 : 13)
    .borderRadius(20)
    .border({ width: 2, color: '#C9A75D' })
    .backgroundColor('#174F45')
    .layoutWeight(1)
    .justifyContent(FlexAlign.SpaceBetween)
  }

  @Builder
  ChineseChessBoardSurface() {
    Column({ space: 7 }) {
      Row() {
        Text('楚河汉界')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFF3D8')
          .layoutWeight(1)
        Text('棋子落在交叉点 · 红方先行')
          .fontSize(9)
          .fontColor('#E8D5BB')
      }
      Grid() {
        ForEach(this.view.board, (cell: string, index: number) => {
          this.ChineseChessCell(cell, index)
        }, (cell: string, index: number) => index.toString() + '-' + cell)
      }
      .columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr 1fr 1fr 1fr')
      .rowsTemplate('1fr 1fr 1fr 1fr 1fr 1fr 1fr 1fr 1fr 1fr')
      .width('100%')
      .aspectRatio(0.89)
      .padding(8)
      .borderRadius(10)
      .border({ width: 2, color: '#8E582F' })
      .backgroundColor('#D3A960')
    }
    .width(this.isLandscapeLayout() ? this.chessLandscapeBoardWidth() : '100%')
    .padding(10)
    .borderRadius(18)
    .backgroundColor('#795236')
  }

  @Builder
  ChineseChessArena() {
    if (this.isLandscapeLayout()) {
      Row({ space: 12 }) {
        this.ChineseChessBoardSurface()
        Column({ space: 10 }) {
          Text(this.view.status)
            .width('100%')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor('#3E2B20')
          Text(this.view.prompt)
            .width('100%')
            .fontSize(11)
            .fontColor('#735B48')
          if (this.view.history.length > 0) {
            Text('最近着法')
              .width('100%')
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
            ForEach(this.view.history.slice(Math.max(0, this.view.history.length - 5)), (line: string) => {
              Text(line)
                .width('100%')
                .fontSize(10)
                .fontColor('#6C5543')
            }, (line: string, index: number) => index.toString() + line)
          }
          Text('点击己方棋子，再点击目标交叉点。受到将军时必须先应将。')
            .width('100%')
            .fontSize(10)
            .lineHeight(16)
            .fontColor('#315D47')
            .padding(10)
            .borderRadius(10)
            .backgroundColor('#E3EFE4')
        }
        .layoutWeight(1)
        .padding(12)
        .borderRadius(16)
        .backgroundColor('#FFFDF8')
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
      .layoutWeight(1)
    } else {
      this.ChineseChessBoardSurface()
    }
  }

  @Builder
  LandscapeGameHeader() {
    Row({ space: 8 }) {
      Button('结束')
        .height(34)
        .fontSize(10)
        .fontColor('#6B4330')
        .backgroundColor('#F1E4CF')
        .onClick(() => {
          this.leaveRoom();
        })
      this.GameTypeIcon()
      Column({ space: 0 }) {
        Text(this.view.title)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
        Text('第 ' + this.view.round.toString() + ' 轮 · ' + this.view.currentPlayerName)
          .fontSize(9)
          .fontColor('#7C6250')
      }
      .alignItems(HorizontalAlign.Center)
      .layoutWeight(1)
      Button(this.landscapeRequested ? '自动旋转' : '横屏')
        .height(34)
        .fontSize(10)
        .fontColor('#4D3323')
        .backgroundColor('#E9D8BC')
        .onClick(() => {
          this.toggleLandscape();
        })
      Button('刷新')
        .height(34)
        .fontSize(10)
        .fontColor('#4D3323')
        .backgroundColor('#F1E4CF')
        .onClick(() => {
          this.refresh();
        })
    }
    .width('100%')
    .height(48)
    .padding({ left: 12, right: 12, top: 5, bottom: 5 })
  }

  @Builder
  LandscapeGamePage() {
    Column({ space: 4 }) {
      this.LandscapeGameHeader()
      if (this.view.gameId === GameId.LANDLORD) {
        this.LandlordTable()
      } else if (this.view.gameId === GameId.SICHUAN_MAHJONG) {
        this.MahjongTable()
      } else {
        this.ChineseChessArena()
      }
      Text(this.message)
        .width('100%')
        .height(27)
        .fontSize(9)
        .fontColor('#6D5543')
        .padding({ left: 12, right: 12, top: 5 })
        .backgroundColor('#F1E4CF')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FAF4E9')
    .onAreaChange((oldValue: Area, newValue: Area) => {
      this.pageWidth = Number(newValue.width);
      this.pageHeight = Number(newValue.height);
    })
  }

  build() {
    if (this.supportsLandscapeTable()) {
      this.LandscapeGamePage()
    } else {
      Column() {
      Row() {
        Button('结束')
          .height(36)
          .fontSize(11)
          .fontColor('#6B4330')
          .backgroundColor('#F1E4CF')
          .onClick(() => {
            this.leaveRoom();
          })
        this.GameTypeIcon()
        Column({ space: 2 }) {
          Text(this.view.title)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
          Text('第 ' + this.view.round.toString() + ' 轮 · ' + this.view.currentPlayerName)
            .fontSize(10)
            .fontColor('#7C6250')
        }
        .alignItems(HorizontalAlign.Center)
        .layoutWeight(1)
        if (this.supportsLandscapeTable()) {
          Button(this.landscapeRequested ? '自动旋转' : '横屏')
            .height(36)
            .fontSize(10)
            .fontColor('#4D3323')
            .backgroundColor('#E9D8BC')
            .margin({ right: 6 })
            .onClick(() => {
              this.toggleLandscape();
            })
        }
        Button('刷新')
          .height(36)
          .fontSize(11)
          .fontColor('#4D3323')
          .backgroundColor('#F1E4CF')
          .onClick(() => {
            this.refresh();
          })
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 12, bottom: 8 })

      Scroll() {
        Column({ space: 12 }) {
          if (!(this.isLandscapeLayout() && this.supportsLandscapeTable())) {
            Scroll() {
              Row({ space: 7 }) {
                ForEach(this.players, (player: RoomPlayer, index: number) => {
                  this.SeatChip(player, index)
                }, (player: RoomPlayer) => player.id)
              }
            }
            .scrollable(ScrollDirection.Horizontal)
            .scrollBar(BarState.Off)
            .width('100%')
          }

          if (this.view.gameId !== GameId.LANDLORD && this.view.gameId !== GameId.SICHUAN_MAHJONG &&
            this.view.gameId !== GameId.CHINESE_CHESS) {
            Column({ space: 5 }) {
              Text(this.view.status)
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor('#3F2A1E')
              if (this.view.prompt.length > 0) {
                Text(this.view.prompt)
                  .fontSize(11)
                  .fontColor('#806650')
              }
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding(14)
            .borderRadius(16)
            .backgroundColor('#F1E4CF')
          }

          if (this.view.privateText.length > 0 && this.view.gameId !== GameId.LANDLORD &&
            this.view.gameId !== GameId.SICHUAN_MAHJONG) {
            this.PrivatePanel()
          }

          if (this.view.gameId === GameId.LANDLORD) {
            this.LandlordTable()
          } else if (this.view.gameId === GameId.SICHUAN_MAHJONG) {
            this.MahjongTable()
          } else if (this.view.gameId === GameId.CHINESE_CHESS) {
            this.ChineseChessArena()
          }

          if (this.view.gameId === GameId.DRAW_GUESS) {
            Column({ space: 8 }) {
              Row() {
                Text(this.canDraw() ? '你的画板' : '画家正在作画')
                  .fontSize(13)
                  .fontWeight(FontWeight.Bold)
                  .layoutWeight(1)
                if (this.canDraw()) {
                  Button('清空')
                    .height(32)
                    .fontSize(10)
                    .fontColor('#513829')
                    .backgroundColor('#F1E4CF')
                    .onClick(() => {
                      this.clearCanvas();
                    })
                }
              }
              Canvas(this.canvasContext)
                .width('100%')
                .height(280)
                .backgroundColor('#FFFDF8')
                .border({ width: 1, color: '#D8C4A7' })
                .borderRadius(14)
                .onReady(() => {
                  this.canvasContext.strokeStyle = '#5A3A28';
                  this.canvasContext.lineWidth = 4;
                  this.canvasContext.lineCap = 'round';
                  this.canvasContext.lineJoin = 'round';
                })
                .onTouch((event: TouchEvent) => {
                  this.handleDrawTouch(event);
                })
            }
            .width('100%')
            .padding(12)
            .borderRadius(17)
            .backgroundColor('#F6EADB')
          }

          if (this.view.board.length > 0 && this.view.gameId !== GameId.CHINESE_CHESS) {
            Column({ space: 8 }) {
              Row() {
                Text(this.view.gameId === GameId.JUNQI ? '军棋战场' :
                  (this.view.gameId === GameId.LUDO ? '飞行跑道' : '棋局'))
                  .fontSize(13)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#FFF4DE')
                  .layoutWeight(1)
                Text(this.view.gameId === GameId.JUNQI ? '铁路 · 行营 · 暗棋' :
                  '点击落子')
                  .fontSize(9)
                  .fontColor('#E8D5BB')
              }
              .width('100%')
              Grid() {
                ForEach(this.view.board, (cell: string, index: number) => {
                  this.GameBoardCell(cell, index)
                }, (cell: string, index: number) => index.toString() + '-' + cell)
              }
              .columnsTemplate('1fr '.repeat(Math.max(1, this.view.columns)).trim())
              .rowsTemplate('1fr '.repeat(Math.ceil(this.view.board.length /
                Math.max(1, this.view.columns))).trim())
              .columnsGap(this.view.gameId === GameId.JUNQI ? 3 : 0)
              .rowsGap(this.view.gameId === GameId.JUNQI ? 3 : 0)
              .width('100%')
              .aspectRatio(this.boardAspectRatio())
              .padding(this.view.gameId === GameId.JUNQI ? 8 : 5)
              .borderRadius(13)
              .backgroundColor(this.view.gameId === GameId.REVERSI ? '#28583B' : '#D3A960')
            }
            .width('100%')
            .padding(11)
            .borderRadius(18)
            .backgroundColor('#795236')
          }

          if (this.view.hand.length > 0 && this.view.gameId !== GameId.LANDLORD &&
            this.view.gameId !== GameId.SICHUAN_MAHJONG) {
            Column({ space: 8 }) {
              Text('你的手牌 · ' + this.view.hand.length.toString() + ' 张')
                .width('100%')
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
              Scroll() {
                Row() {
                  ForEach(this.view.hand, (card: string, index: number) => {
                    this.CardFace(card, index)
                  }, (card: string, index: number) => index.toString() + '-' + card)
                  Blank().width(8)
                }
              }
              .scrollable(ScrollDirection.Horizontal)
              .scrollBar(BarState.Off)
              .width('100%')
              .height(104)
              if (this.isMultiSelectGame()) {
                Row({ space: 8 }) {
                  Button('清空选择')
                    .layoutWeight(1)
                    .height(40)
                    .fontColor('#513829')
                    .backgroundColor('#F1E4CF')
                    .onClick(() => {
                      this.selectedCardIndexes = [];
                    })
                  Button('出牌（' + this.selectedCardIndexes.length.toString() + '）')
                    .layoutWeight(1)
                    .height(40)
                    .backgroundColor('#6B4330')
                    .onClick(() => {
                      this.playSelectedCards();
                    })
                }
                .width('100%')
              }
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding(14)
            .borderRadius(18)
            .backgroundColor('#F6EADB')
          }

          if (this.view.choices.length > 0 && this.view.gameId !== GameId.LANDLORD &&
            this.view.gameId !== GameId.SICHUAN_MAHJONG) {
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(this.view.choices, (choice: GameChoice) => {
                this.ChoiceButton(choice)
              }, (choice: GameChoice) => choice.id)
            }
            .width('100%')
          }

          if (this.view.gameId === GameId.DRAW_GUESS || this.view.gameId === GameId.NUMBER_BOMB) {
            Row({ space: 8 }) {
              TextInput({ text: this.answer, placeholder: this.view.gameId === GameId.NUMBER_BOMB ?
                '输入范围内数字' : '输入你的答案' })
                .layoutWeight(1)
                .height(42)
                .backgroundColor('#FFFDF8')
                .borderRadius(12)
                .onChange((value: string) => {
                  this.answer = value;
                })
              Button('提交')
                .height(42)
                .backgroundColor('#6B4330')
                .onClick(() => {
                  this.submitAnswer();
                })
            }
            .width('100%')
          }

          if (this.view.history.length > 0 && !(this.view.gameId === GameId.CHINESE_CHESS &&
            this.isLandscapeLayout())) {
            Column({ space: 5 }) {
              Text('对局记录')
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
              ForEach(this.view.history.slice(Math.max(0, this.view.history.length - 6)), (line: string) => {
                Text(line)
                  .width('100%')
                  .fontSize(10)
                  .fontColor('#705744')
              }, (line: string, index: number) => index.toString() + line)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding(13)
            .borderRadius(15)
            .backgroundColor('#FFFDF8')
          }

          if (this.view.phase === RoomPhase.FINISHED) {
            Column({ space: 10 }) {
              Text('本局结束')
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
              Text(this.view.winner)
                .fontSize(14)
                .textAlign(TextAlign.Center)
              Button('返回大厅')
                .width('100%')
                .height(46)
                .backgroundColor('#6B4330')
                .onClick(() => {
                  this.leaveRoom();
                })
            }
            .width('100%')
            .padding(18)
            .borderRadius(20)
            .backgroundColor('#E3EEDA')
          }

          Text(this.message)
            .width('100%')
            .fontSize(11)
            .fontColor('#765B48')
            .padding(11)
            .borderRadius(12)
            .backgroundColor('#F1E4CF')
        }
        .width('100%')
        .padding({ left: 14, right: 14, bottom: 28 })
      }
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FAF4E9')
      .onAreaChange((oldValue: Area, newValue: Area) => {
        this.pageWidth = Number(newValue.width);
        this.pageHeight = Number(newValue.height);
      })
    }
  }
}
