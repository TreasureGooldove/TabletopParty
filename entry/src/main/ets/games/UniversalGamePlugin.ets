import {
  ActionResult,
  GameAction,
  GameChoice,
  GameDefinition,
  GameId,
  GamePlugin,
  GameView,
  RoomPhase,
  RoomPlayer
} from '../core/GameContracts';
import { GameCatalog } from './GameCatalog';
import { BuiltInContent } from '../services/BuiltInContent';

class SeededRandom {
  private value: number;

  constructor(seed: number) {
    this.value = Math.max(1, Math.abs(seed) % 2147483647);
  }

  public next(max: number): number {
    this.value = this.value * 48271 % 2147483647;
    return max <= 0 ? 0 : this.value % max;
  }
}

enum ClimbingPatternType {
  INVALID = 'invalid',
  SINGLE = 'single',
  PAIR = 'pair',
  TRIPLE = 'triple',
  TRIPLE_SINGLE = 'tripleSingle',
  TRIPLE_PAIR = 'triplePair',
  STRAIGHT = 'straight',
  PAIR_STRAIGHT = 'pairStraight',
  AIRPLANE = 'airplane',
  AIRPLANE_SINGLE = 'airplaneSingle',
  AIRPLANE_PAIR = 'airplanePair',
  FOUR_TWO = 'fourTwo',
  FOUR_TWO_PAIR = 'fourTwoPair',
  BOMB = 'bomb',
  ROCKET = 'rocket'
}

class ClimbingPattern {
  public type: ClimbingPatternType = ClimbingPatternType.INVALID;
  public mainRank: number = -1;
  public length: number = 0;
  public tripleCount: number = 0;
}

export class UniversalGamePlugin implements GamePlugin {
  private definition: GameDefinition;
  private phase: RoomPhase = RoomPhase.LOBBY;
  private revision: number = 0;
  private turnIndex: number = 0;
  private round: number = 1;
  private status: string = '';
  private prompt: string = '';
  private winner: string = '';
  private board: string[] = [];
  private hands: string[][] = [];
  private deck: string[] = [];
  private discard: string[] = [];
  private secrets: string[] = [];
  private scores: number[] = [];
  private alive: boolean[] = [];
  private votes: number[] = [];
  private acted: boolean[] = [];
  private numbers: number[] = [];
  private history: string[] = [];
  private currentColor: string = '红';
  private direction: number = 1;
  private pendingDraw: number = 0;
  private selectedIndex: number = -1;
  private random: SeededRandom = new SeededRandom(1);
  private drawWord: string = '';
  private numberLow: number = 1;
  private numberHigh: number = 100;
  private numberBomb: number = 50;
  private lastPlayCards: string[] = [];
  private lastPlayPlayer: number = -1;
  private passCount: number = 0;
  private multiplier: number = 1;
  private landlordIndex: number = -1;
  private landlordBids: number[] = [];
  private landlordBottom: string[] = [];
  private chessPositions: string[] = [];
  private chessHalfMoves: number = 0;
  private werewolfRoles: string[] = [];
  private werewolfStage: string = '';
  private werewolfNightTarget: number = -1;
  private werewolfGuardTarget: number = -1;
  private werewolfLastGuard: number = -1;
  private witchSaveAvailable: boolean = true;
  private witchPoisonAvailable: boolean = true;
  private mahjongStage: string = '';
  private mahjongMissing: string[] = [];
  private mahjongExchangeIndexes: number[][] = [];
  private playerDiscards: string[][] = [];
  private declaredLastCard: boolean[] = [];

  constructor(id: GameId) {
    this.definition = GameCatalog.find(id);
  }

  public getDefinition(): GameDefinition {
    return this.definition;
  }

  public start(players: RoomPlayer[], seed: number): ActionResult {
    if (players.length < this.definition.minPlayers) {
      return new ActionResult(false, '至少需要 ' + this.definition.minPlayers.toString() + ' 名玩家');
    }
    this.random = new SeededRandom(seed);
    this.phase = RoomPhase.PLAYING;
    this.revision = 1;
    this.turnIndex = 0;
    this.round = 1;
    this.status = this.definition.title + ' 已开始';
    this.prompt = '';
    this.winner = '';
    this.board = [];
    this.hands = [];
    this.deck = [];
    this.discard = [];
    this.secrets = [];
    this.scores = [];
    this.alive = [];
    this.votes = [];
    this.acted = [];
    this.numbers = [];
    this.history = [];
    this.currentColor = '红';
    this.direction = 1;
    this.pendingDraw = 0;
    this.selectedIndex = -1;
    this.lastPlayCards = [];
    this.lastPlayPlayer = -1;
    this.passCount = 0;
    this.multiplier = 1;
    this.landlordIndex = -1;
    this.landlordBids = [];
    this.landlordBottom = [];
    this.chessPositions = [];
    this.chessHalfMoves = 0;
    this.werewolfRoles = [];
    this.werewolfStage = '';
    this.werewolfNightTarget = -1;
    this.werewolfGuardTarget = -1;
    this.werewolfLastGuard = -1;
    this.witchSaveAvailable = true;
    this.witchPoisonAvailable = true;
    this.mahjongStage = '';
    this.mahjongMissing = [];
    this.mahjongExchangeIndexes = [];
    this.playerDiscards = [];
    this.declaredLastCard = [];
    for (let index: number = 0; index < players.length; index += 1) {
      this.hands.push([]);
      this.secrets.push('');
      this.scores.push(0);
      this.alive.push(true);
      this.votes.push(-1);
      this.acted.push(false);
      this.declaredLastCard.push(false);
      this.playerDiscards.push([]);
    }
    this.prepare(players);
    return new ActionResult(true, this.status);
  }

  public perform(action: GameAction, players: RoomPlayer[]): ActionResult {
    if (this.phase === RoomPhase.FINISHED) {
      return new ActionResult(false, '本局已经结束');
    }
    const actorIndex: number = this.findPlayer(players, action.actorId);
    if (actorIndex < 0) {
      return new ActionResult(false, '玩家不在当前房间');
    }
    let result: ActionResult;
    if (this.definition.id === GameId.GOMOKU) {
      result = this.placeGomoku(actorIndex, action.value, players);
    } else if (this.definition.id === GameId.REVERSI) {
      result = this.placeReversi(actorIndex, action.value, players);
    } else if (this.definition.id === GameId.CHINESE_CHESS) {
      result = this.moveChineseChess(actorIndex, action.value, players);
    } else if (this.definition.id === GameId.JUNQI) {
      result = this.moveJunqi(actorIndex, action.value, players);
    } else if (this.definition.id === GameId.UNDERCOVER) {
      result = this.playUndercover(actorIndex, action, players);
    } else if (this.definition.id === GameId.WEREWOLF) {
      result = this.playWerewolf(actorIndex, action, players);
    } else if (this.definition.id === GameId.COLOR_CLASH) {
      result = this.playColorCard(actorIndex, action, players);
    } else if (this.definition.id === GameId.LUDO) {
      result = this.playLudo(actorIndex, action, players);
    } else if (this.definition.id === GameId.NUMBER_BOMB) {
      result = this.playNumberBomb(actorIndex, action, players);
    } else if (this.definition.id === GameId.DRAW_GUESS) {
      result = this.playDrawGuess(actorIndex, action, players);
    } else if (this.definition.id === GameId.CHARADES || this.definition.id === GameId.TRUTH_DARE) {
      result = this.playPromptGame(actorIndex, action, players);
    } else if (this.definition.id === GameId.SICHUAN_MAHJONG) {
      result = this.playMahjong(actorIndex, action, players);
    } else {
      result = this.playClimbingCards(actorIndex, action, players);
    }
    if (result.success) {
      this.revision += 1;
    }
    return result;
  }

  public getView(playerId: string, players: RoomPlayer[]): GameView {
    const view: GameView = new GameView();
    view.gameId = this.definition.id;
    view.title = this.definition.title;
    view.phase = this.phase;
    view.status = this.status;
    view.prompt = this.prompt;
    view.winner = this.winner;
    view.round = this.round;
    view.board = this.maskedBoard(playerId, players);
    view.boardOwners = this.boardOwners();
    view.selectedBoardIndex = this.selectedIndex;
    view.history = this.history.slice();
    view.scores = this.scores.slice();
    view.alive = this.alive.slice();
    view.columns = this.boardColumns();
    view.tableCards = this.lastPlayCards.slice();
    view.bottomCards = this.landlordIndex >= 0 ? this.landlordBottom.slice() : ['', '', ''];
    view.landlordSeat = this.landlordIndex;
    view.multiplier = this.multiplier;
    view.remainingCards = this.deck.length;
    view.missingSuits = this.mahjongMissing.slice();
    view.gameStage = this.definition.id === GameId.SICHUAN_MAHJONG ? this.mahjongStage : this.phase;
    for (let index: number = 0; index < this.hands.length; index += 1) {
      view.handCounts.push(this.hands[index].length);
    }
    for (let index: number = 0; index < this.playerDiscards.length; index += 1) {
      view.playerDiscards.push(this.playerDiscards[index].slice());
    }
    const playerIndex: number = this.findPlayer(players, playerId);
    if (playerIndex >= 0) {
      view.privateText = this.secrets[playerIndex];
      if (playerIndex < this.hands.length) {
        view.hand = this.hands[playerIndex].slice();
      }
      view.canAct = this.canPlayerAct(playerIndex);
    }
    if (players.length > this.turnIndex) {
      view.currentPlayerId = players[this.turnIndex].id;
      view.currentPlayerName = players[this.turnIndex].nickname;
    }
    view.choices = this.buildChoices(playerIndex, players);
    return view;
  }

  public getPhase(): RoomPhase {
    return this.phase;
  }

  public getRevision(): number {
    return this.revision;
  }

  public isFinished(): boolean {
    return this.phase === RoomPhase.FINISHED;
  }

  private prepare(players: RoomPlayer[]): void {
    if (this.definition.id === GameId.GOMOKU) {
      this.board = this.emptyBoard(225);
      this.status = players[0].nickname + ' 执黑先行';
    } else if (this.definition.id === GameId.REVERSI) {
      this.board = this.emptyBoard(64);
      this.board[27] = '○';
      this.board[28] = '●';
      this.board[35] = '●';
      this.board[36] = '○';
      this.status = players[0].nickname + ' 执黑先行';
    } else if (this.definition.id === GameId.CHINESE_CHESS) {
      this.prepareChineseChess();
      this.status = players[0].nickname + ' 执红先行';
    } else if (this.definition.id === GameId.JUNQI) {
      this.prepareJunqi(players);
    } else if (this.definition.id === GameId.UNDERCOVER) {
      this.prepareUndercover(players);
    } else if (this.definition.id === GameId.WEREWOLF) {
      this.prepareWerewolf(players);
    } else if (this.definition.id === GameId.COLOR_CLASH) {
      this.prepareColorCards(players);
    } else if (this.definition.id === GameId.LUDO) {
      for (let index: number = 0; index < players.length * 4; index += 1) {
        this.numbers.push(-1);
      }
      this.refreshLudoBoard(players);
      this.status = players[0].nickname + ' 掷骰开始';
    } else if (this.definition.id === GameId.NUMBER_BOMB) {
      this.numberBomb = 1 + this.random.next(100);
      this.prompt = '范围 1–100';
      this.status = players[0].nickname + ' 先猜一个数字';
    } else if (this.definition.id === GameId.DRAW_GUESS) {
      this.drawWord = this.randomPrompt('draw');
      this.secrets[0] = '本轮题目：' + this.drawWord;
      this.prompt = '画家正在作画，其他玩家输入答案';
      this.status = players[0].nickname + ' 是本轮画家';
    } else if (this.definition.id === GameId.CHARADES || this.definition.id === GameId.TRUTH_DARE) {
      this.preparePromptRound(players);
    } else if (this.definition.id === GameId.SICHUAN_MAHJONG) {
      this.prepareMahjong(players);
    } else {
      this.prepareClimbingCards(players);
    }
  }

  private prepareUndercover(players: RoomPlayer[]): void {
    const pairs: string[][] = BuiltInContent.undercoverPairs();
    const pair: string[] = pairs[this.random.next(pairs.length)];
    const spyIndex: number = this.random.next(players.length);
    for (let index: number = 0; index < players.length; index += 1) {
      this.secrets[index] = '你的词语：' + (index === spyIndex ? pair[1] : pair[0]);
      this.numbers.push(index === spyIndex ? 1 : 0);
    }
    this.phase = RoomPhase.REVEAL;
    this.status = players[0].nickname + ' 查看词语后开始描述';
    this.prompt = '不要直接说出词语';
  }

  private playUndercover(actorIndex: number, action: GameAction, players: RoomPlayer[]): ActionResult {
    if (this.phase === RoomPhase.REVEAL || this.phase === RoomPhase.PLAYING) {
      if (actorIndex !== this.turnIndex) {
        return new ActionResult(false, '还没轮到你描述');
      }
      this.phase = RoomPhase.PLAYING;
      this.history.push(players[actorIndex].nickname + ' 已完成描述');
      this.nextAliveTurn(players);
      if (this.turnIndex === 0) {
        this.phase = RoomPhase.VOTING;
        this.resetVotes();
        this.status = '描述结束，请投票选出卧底';
      } else {
        this.status = '轮到 ' + players[this.turnIndex].nickname + ' 描述';
      }
      return new ActionResult(true, this.status);
    }
    if (this.phase !== RoomPhase.VOTING || action.type !== 'vote') {
      return new ActionResult(false, '当前需要投票');
    }
    if (!this.alive[actorIndex] || action.value < 0 || action.value >= players.length ||
      !this.alive[action.value] || action.value === actorIndex) {
      return new ActionResult(false, '投票目标无效');
    }
    if (this.votes[actorIndex] >= 0) {
      return new ActionResult(false, '本轮已经投过票');
    }
    this.votes[actorIndex] = action.value;
    if (!this.allAliveVoted()) {
      return new ActionResult(true, players[actorIndex].nickname + ' 已投票');
    }
    const eliminated: number = this.voteWinner(players.length);
    if (eliminated < 0) {
      this.resetVotes();
      return new ActionResult(true, '票数相同，请重新投票');
    }
    this.alive[eliminated] = false;
    this.history.push(players[eliminated].nickname + ' 被淘汰');
    if (this.numbers[eliminated] === 1) {
      this.finish('平民阵营获胜，卧底是 ' + players[eliminated].nickname);
    } else if (this.aliveCount() <= 2) {
      let spyName: string = '';
      for (let index: number = 0; index < players.length; index += 1) {
        if (this.numbers[index] === 1) {
          spyName = players[index].nickname;
        }
      }
      this.finish('卧底阵营获胜，卧底是 ' + spyName);
    } else {
      this.round += 1;
      this.turnIndex = this.firstAlive();
      this.phase = RoomPhase.PLAYING;
      this.status = '第 ' + this.round.toString() + ' 轮描述开始';
      this.resetVotes();
    }
    return new ActionResult(true, this.status);
  }

  private prepareWerewolf(players: RoomPlayer[]): void {
    const roles: string[] = [];
    const wolfCount: number = players.length >= 9 ? 3 : 2;
    for (let index: number = 0; index < wolfCount; index += 1) {
      roles.push('狼人');
    }
    roles.push('预言家');
    roles.push('女巫');
    if (players.length >= 8) {
      roles.push('猎人');
    }
    if (players.length >= 10) {
      roles.push('守卫');
    }
    while (roles.length < players.length) {
      roles.push('村民');
    }
    this.shuffle(roles);
    this.werewolfRoles = roles.slice();
    for (let index: number = 0; index < players.length; index += 1) {
      this.secrets[index] = '你的身份：' + roles[index];
      this.numbers.push(roles[index] === '狼人' ? 1 : 0);
    }
    for (let index: number = 0; index < players.length; index += 1) {
      if (roles[index] === '狼人') {
        let teammates: string = '';
        for (let other: number = 0; other < players.length; other += 1) {
          if (other !== index && roles[other] === '狼人') {
            teammates += (teammates.length > 0 ? '、' : '') + players[other].nickname;
          }
        }
        this.secrets[index] += '；狼队友：' + teammates;
      }
    }
    this.beginWerewolfNight(players);
  }

  private playWerewolf(actorIndex: number, action: GameAction, players: RoomPlayer[]): ActionResult {
    if (this.phase === RoomPhase.PLAYING) {
      return this.playWerewolfNight(actorIndex, action, players);
    }
    if (this.phase !== RoomPhase.VOTING || action.type !== 'vote') {
      return new ActionResult(false, '当前等待白天投票');
    }
    if (!this.alive[actorIndex] || action.value < 0 || action.value >= players.length ||
      !this.alive[action.value]) {
      return new ActionResult(false, '投票目标无效');
    }
    if (this.votes[actorIndex] >= 0) {
      return new ActionResult(false, '本轮已经投过票');
    }
    this.votes[actorIndex] = action.value;
    if (!this.allAliveVoted()) {
      return new ActionResult(true, players[actorIndex].nickname + ' 已完成白天投票');
    }
    const eliminated: number = this.voteWinner(players.length);
    if (eliminated >= 0) {
      this.alive[eliminated] = false;
      this.history.push('白天放逐：' + players[eliminated].nickname);
      if (this.werewolfRoles[eliminated] === '猎人') {
        this.phase = RoomPhase.PLAYING;
        this.werewolfStage = 'hunter';
        this.turnIndex = eliminated;
        this.status = players[eliminated].nickname + ' 是猎人，可以开枪带走一名玩家';
        return new ActionResult(true, this.status);
      }
    } else {
      this.history.push('白天平票，无人放逐');
    }
    if (!this.checkWerewolfWin(players)) {
      this.round += 1;
      this.resetVotes();
      this.beginWerewolfNight(players);
    }
    return new ActionResult(true, this.status);
  }

  private beginWerewolfNight(players: RoomPlayer[]): void {
    this.phase = RoomPhase.PLAYING;
    this.werewolfStage = 'wolf';
    this.werewolfNightTarget = -1;
    this.werewolfGuardTarget = -1;
    this.turnIndex = this.firstAliveRole('狼人');
    this.prompt = '按狼人、预言家、守卫、女巫的顺序私密行动';
    this.status = '第 ' + this.round.toString() + ' 夜：狼人请选择目标';
    if (this.turnIndex < 0) {
      this.finish('好人阵营获胜');
    }
  }

  private playWerewolfNight(actorIndex: number, action: GameAction, players: RoomPlayer[]): ActionResult {
    if (this.werewolfStage === 'hunter') {
      if (actorIndex !== this.turnIndex || action.type !== 'hunterShoot' && action.type !== 'hunterSkip') {
        return new ActionResult(false, '等待猎人决定是否开枪');
      }
      if (action.type === 'hunterShoot' && action.value >= 0 && action.value < players.length &&
        this.alive[action.value]) {
        this.alive[action.value] = false;
        this.history.push('猎人带走：' + players[action.value].nickname);
      }
      if (!this.checkWerewolfWin(players)) {
        this.round += 1;
        this.resetVotes();
        this.beginWerewolfNight(players);
      }
      return new ActionResult(true, this.status);
    }
    if (actorIndex !== this.turnIndex || !this.alive[actorIndex]) {
      return new ActionResult(false, '还没轮到该角色行动');
    }
    if (this.werewolfStage === 'wolf') {
      if (action.type !== 'wolfKill' || !this.validAliveTarget(action.value, players.length) ||
        this.werewolfRoles[action.value] === '狼人') {
        return new ActionResult(false, '狼人请选择一名存活的非狼人玩家');
      }
      this.werewolfNightTarget = action.value;
      this.advanceWerewolfStage('seer', players);
      return new ActionResult(true, this.status);
    }
    if (this.werewolfStage === 'seer') {
      if (action.type !== 'seerInspect' || !this.validAliveTarget(action.value, players.length)) {
        return new ActionResult(false, '预言家请选择查验目标');
      }
      this.secrets[actorIndex] = '你的身份：预言家；今夜查验 ' + players[action.value].nickname + ' 是' +
        (this.werewolfRoles[action.value] === '狼人' ? '狼人' : '好人');
      this.advanceWerewolfStage('guard', players);
      return new ActionResult(true, this.status);
    }
    if (this.werewolfStage === 'guard') {
      if (action.type !== 'guard' || !this.validAliveTarget(action.value, players.length) ||
        action.value === this.werewolfLastGuard) {
        return new ActionResult(false, '守卫不能连续两夜守护同一名玩家');
      }
      this.werewolfGuardTarget = action.value;
      this.werewolfLastGuard = action.value;
      this.advanceWerewolfStage('witch', players);
      return new ActionResult(true, this.status);
    }
    if (this.werewolfStage === 'witch') {
      if (action.type === 'witchSave' && this.witchSaveAvailable) {
        this.werewolfNightTarget = -1;
        this.witchSaveAvailable = false;
      } else if (action.type === 'witchPoison' && this.witchPoisonAvailable &&
        this.validAliveTarget(action.value, players.length)) {
        this.alive[action.value] = false;
        this.witchPoisonAvailable = false;
        this.history.push('女巫使用毒药，一名玩家离场');
      } else if (action.type !== 'witchSkip') {
        return new ActionResult(false, '女巫本夜无法执行该操作');
      }
      this.resolveWerewolfNight(players);
      return new ActionResult(true, this.status);
    }
    return new ActionResult(false, '夜晚流程状态异常');
  }

  private advanceWerewolfStage(stage: string, players: RoomPlayer[]): void {
    this.werewolfStage = stage;
    this.turnIndex = this.firstAliveRole(stage === 'seer' ? '预言家' : stage === 'guard' ? '守卫' : '女巫');
    if (this.turnIndex < 0) {
      if (stage === 'witch') {
        this.resolveWerewolfNight(players);
      } else {
        this.advanceWerewolfStage(stage === 'seer' ? 'guard' : 'witch', players);
      }
      return;
    }
    if (stage === 'seer') {
      this.status = '预言家请私密查验一名玩家';
    } else if (stage === 'guard') {
      this.status = '守卫请选择本夜守护目标';
    } else {
      this.status = '女巫请选择是否使用一瓶药';
    }
  }

  private resolveWerewolfNight(players: RoomPlayer[]): void {
    if (this.werewolfNightTarget >= 0 && this.werewolfNightTarget !== this.werewolfGuardTarget) {
      this.alive[this.werewolfNightTarget] = false;
      this.history.push('第 ' + this.round.toString() + ' 夜：' +
        players[this.werewolfNightTarget].nickname + ' 离场');
    } else {
      this.history.push('第 ' + this.round.toString() + ' 夜：平安夜');
    }
    if (!this.checkWerewolfWin(players)) {
      this.phase = RoomPhase.VOTING;
      this.werewolfStage = 'day';
      this.resetVotes();
      this.status = '天亮了，请存活玩家投票';
    }
  }

  private firstAliveRole(role: string): number {
    for (let index: number = 0; index < this.werewolfRoles.length; index += 1) {
      if (this.alive[index] && this.werewolfRoles[index] === role) {
        return index;
      }
    }
    return -1;
  }

  private validAliveTarget(target: number, playerCount: number): boolean {
    return target >= 0 && target < playerCount && this.alive[target];
  }

  private checkWerewolfWin(players: RoomPlayer[]): boolean {
    let wolves: number = 0;
    let villagers: number = 0;
    for (let index: number = 0; index < players.length; index += 1) {
      if (this.alive[index]) {
        if (this.numbers[index] === 1) {
          wolves += 1;
        } else {
          villagers += 1;
        }
      }
    }
    if (wolves === 0) {
      this.finish('好人阵营获胜');
      return true;
    }
    if (wolves >= villagers) {
      this.finish('狼人阵营获胜');
      return true;
    }
    return false;
  }

  private placeGomoku(actorIndex: number, target: number, players: RoomPlayer[]): ActionResult {
    if (actorIndex !== this.turnIndex) {
      return new ActionResult(false, '还没轮到你落子');
    }
    if (target < 0 || target >= this.board.length || this.board[target].length > 0) {
      return new ActionResult(false, '该位置不能落子');
    }
    const symbol: string = actorIndex === 0 ? '●' : '○';
    this.board[target] = symbol;
    this.history.push(players[actorIndex].nickname + ' 落子 ' + target.toString());
    if (this.hasLine(target, symbol, 15, 15, 5)) {
      this.finish(players[actorIndex].nickname + ' 五子连珠获胜');
    } else if (this.boardFull()) {
      this.finish('棋盘已满，本局和棋');
    } else {
      this.turnIndex = (this.turnIndex + 1) % 2;
      this.status = '轮到 ' + players[this.turnIndex].nickname + ' 落子';
    }
    return new ActionResult(true, this.status);
  }

  private placeReversi(actorIndex: number, target: number, players: RoomPlayer[]): ActionResult {
    if (actorIndex !== this.turnIndex) {
      return new ActionResult(false, '还没轮到你落子');
    }
    const symbol: string = actorIndex === 0 ? '●' : '○';
    const flips: number[] = this.reversiFlips(target, symbol);
    if (flips.length === 0) {
      return new ActionResult(false, '必须夹住至少一枚对方棋子');
    }
    this.board[target] = symbol;
    for (let index: number = 0; index < flips.length; index += 1) {
      this.board[flips[index]] = symbol;
    }
    this.turnIndex = (this.turnIndex + 1) % 2;
    const nextSymbol: string = this.turnIndex === 0 ? '●' : '○';
    if (!this.hasReversiMove(nextSymbol)) {
      this.turnIndex = (this.turnIndex + 1) % 2;
      const currentSymbol: string = this.turnIndex === 0 ? '●' : '○';
      if (!this.hasReversiMove(currentSymbol)) {
        this.finishReversi(players);
        return new ActionResult(true, this.status);
      }
      this.history.push(players[(this.turnIndex + 1) % 2].nickname + ' 无棋可下，自动跳过');
    }
    this.status = '轮到 ' + players[this.turnIndex].nickname + ' 落子';
    return new ActionResult(true, this.status);
  }

  private reversiFlips(target: number, symbol: string): number[] {
    const all: number[] = [];
    if (target < 0 || target >= 64 || this.board[target].length > 0) {
      return all;
    }
    const opponent: string = symbol === '●' ? '○' : '●';
    const directions: number[][] = [[-1, -1], [-1, 0], [-1, 1], [0, -1], [0, 1], [1, -1], [1, 0], [1, 1]];
    const row: number = Math.floor(target / 8);
    const column: number = target % 8;
    for (let directionIndex: number = 0; directionIndex < directions.length; directionIndex += 1) {
      const line: number[] = [];
      let nextRow: number = row + directions[directionIndex][0];
      let nextColumn: number = column + directions[directionIndex][1];
      while (nextRow >= 0 && nextRow < 8 && nextColumn >= 0 && nextColumn < 8) {
        const index: number = nextRow * 8 + nextColumn;
        if (this.board[index] === opponent) {
          line.push(index);
        } else {
          if (this.board[index] === symbol && line.length > 0) {
            for (let lineIndex: number = 0; lineIndex < line.length; lineIndex += 1) {
              all.push(line[lineIndex]);
            }
          }
          break;
        }
        nextRow += directions[directionIndex][0];
        nextColumn += directions[directionIndex][1];
      }
    }
    return all;
  }

  private hasReversiMove(symbol: string): boolean {
    for (let index: number = 0; index < this.board.length; index += 1) {
      if (this.reversiFlips(index, symbol).length > 0) {
        return true;
      }
    }
    return false;
  }

  private finishReversi(players: RoomPlayer[]): void {
    let black: number = 0;
    let white: number = 0;
    for (let index: number = 0; index < this.board.length; index += 1) {
      if (this.board[index] === '●') {
        black += 1;
      } else if (this.board[index] === '○') {
        white += 1;
      }
    }
    if (black === white) {
      this.finish('黑白双方 ' + black.toString() + ' 枚，平局');
    } else {
      const winnerIndex: number = black > white ? 0 : 1;
      this.finish(players[winnerIndex].nickname + ' 获胜，比分 ' + black.toString() + ':' + white.toString());
    }
  }

  private prepareChineseChess(): void {
    this.board = this.emptyBoard(90);
    const blackBack: string[] = ['車', '馬', '象', '士', '將', '士', '象', '馬', '車'];
    const redBack: string[] = ['俥', '傌', '相', '仕', '帥', '仕', '相', '傌', '俥'];
    for (let column: number = 0; column < 9; column += 1) {
      this.board[column] = 'B' + blackBack[column];
      this.board[81 + column] = 'R' + redBack[column];
    }
    this.board[19] = 'B炮';
    this.board[25] = 'B炮';
    this.board[64] = 'R炮';
    this.board[70] = 'R炮';
    for (let column: number = 0; column < 9; column += 2) {
      this.board[27 + column] = 'B卒';
      this.board[54 + column] = 'R兵';
    }
    this.chessPositions.push(this.chessPositionSignature('R'));
  }

  private moveChineseChess(actorIndex: number, target: number, players: RoomPlayer[]): ActionResult {
    if (actorIndex !== this.turnIndex) {
      return new ActionResult(false, '还没轮到你走棋');
    }
    if (target < 0 || target >= 90) {
      return new ActionResult(false, '棋盘位置无效');
    }
    const side: string = actorIndex === 0 ? 'R' : 'B';
    if (this.selectedIndex < 0) {
      if (this.board[target].indexOf(side) !== 0) {
        return new ActionResult(false, '请选择自己的棋子');
      }
      this.selectedIndex = target;
      return new ActionResult(true, '已选择 ' + this.board[target].substring(1));
    }
    if (this.board[target].indexOf(side) === 0) {
      this.selectedIndex = target;
      return new ActionResult(true, '已改选 ' + this.board[target].substring(1));
    }
    const source: number = this.selectedIndex;
    if (!this.isLegalChineseMove(source, target, side)) {
      return new ActionResult(false, '该走法不符合棋子规则');
    }
    const captured: string = this.board[target];
    const movedPiece: string = this.board[source].substring(1);
    const snapshot: string[] = this.board.slice();
    this.board[target] = this.board[source];
    this.board[source] = '';
    if (this.generalsFacing() || this.isGeneralAttacked(side)) {
      this.board = snapshot;
      return new ActionResult(false, '该走法会造成将帅照面或己方被将军');
    }
    this.selectedIndex = -1;
    if (captured === (side === 'R' ? 'B將' : 'R帥')) {
      this.finish(players[actorIndex].nickname + ' 将死对方获胜');
    } else {
      const opponent: string = side === 'R' ? 'B' : 'R';
      if (!this.hasLegalChineseMove(opponent)) {
        this.finish(players[actorIndex].nickname + (this.isGeneralAttacked(opponent) ? ' 将死对方获胜' : ' 困毙对方获胜'));
      } else {
        this.turnIndex = (this.turnIndex + 1) % 2;
        this.chessHalfMoves = captured.length > 0 || movedPiece === '兵' || movedPiece === '卒' ?
          0 : this.chessHalfMoves + 1;
        const signature: string = this.chessPositionSignature(opponent);
        this.chessPositions.push(signature);
        if (this.positionCount(signature) >= 3) {
          this.finish('局面三次重复，本局和棋');
        } else if (this.chessHalfMoves >= 120) {
          this.finish('连续六十回合无吃子或兵卒推进，本局和棋');
        } else {
          this.status = (this.isGeneralAttacked(opponent) ? '将军！' : '') +
            '轮到 ' + players[this.turnIndex].nickname + ' 走棋';
        }
      }
    }
    return new ActionResult(true, this.status);
  }

  private isLegalChineseMove(source: number, target: number, side: string): boolean {
    const sourceRow: number = Math.floor(source / 9);
    const sourceColumn: number = source % 9;
    const targetRow: number = Math.floor(target / 9);
    const targetColumn: number = target % 9;
    const rowDistance: number = Math.abs(targetRow - sourceRow);
    const columnDistance: number = Math.abs(targetColumn - sourceColumn);
    const piece: string = this.board[source].substring(1);
    if (piece === '車' || piece === '俥' || piece === '炮') {
      if (sourceRow !== targetRow && sourceColumn !== targetColumn) {
        return false;
      }
      const blockers: number = this.lineBlockers(source, target);
      return piece === '炮' && this.board[target].length > 0 ? blockers === 1 : blockers === 0;
    }
    if (piece === '馬' || piece === '傌') {
      if (!((rowDistance === 2 && columnDistance === 1) || (rowDistance === 1 && columnDistance === 2))) {
        return false;
      }
      const legRow: number = sourceRow + (rowDistance === 2 ? (targetRow > sourceRow ? 1 : -1) : 0);
      const legColumn: number = sourceColumn + (columnDistance === 2 ? (targetColumn > sourceColumn ? 1 : -1) : 0);
      return this.board[legRow * 9 + legColumn].length === 0;
    }
    if (piece === '象' || piece === '相') {
      if (rowDistance !== 2 || columnDistance !== 2) {
        return false;
      }
      if (side === 'R' && targetRow < 5 || side === 'B' && targetRow > 4) {
        return false;
      }
      const eye: number = ((sourceRow + targetRow) / 2) * 9 + (sourceColumn + targetColumn) / 2;
      return this.board[eye].length === 0;
    }
    if (piece === '士' || piece === '仕') {
      return rowDistance === 1 && columnDistance === 1 && this.inPalace(targetRow, targetColumn, side);
    }
    if (piece === '將' || piece === '帥') {
      return rowDistance + columnDistance === 1 && this.inPalace(targetRow, targetColumn, side);
    }
    if (piece === '卒' || piece === '兵') {
      const forward: number = side === 'R' ? -1 : 1;
      if (targetRow - sourceRow === forward && columnDistance === 0) {
        return true;
      }
      const crossed: boolean = side === 'R' ? sourceRow <= 4 : sourceRow >= 5;
      return crossed && rowDistance === 0 && columnDistance === 1;
    }
    return false;
  }

  private lineBlockers(source: number, target: number): number {
    const sourceRow: number = Math.floor(source / 9);
    const sourceColumn: number = source % 9;
    const targetRow: number = Math.floor(target / 9);
    const targetColumn: number = target % 9;
    let blockers: number = 0;
    if (sourceRow === targetRow) {
      for (let column: number = Math.min(sourceColumn, targetColumn) + 1;
        column < Math.max(sourceColumn, targetColumn); column += 1) {
        if (this.board[sourceRow * 9 + column].length > 0) {
          blockers += 1;
        }
      }
    } else {
      for (let row: number = Math.min(sourceRow, targetRow) + 1; row < Math.max(sourceRow, targetRow); row += 1) {
        if (this.board[row * 9 + sourceColumn].length > 0) {
          blockers += 1;
        }
      }
    }
    return blockers;
  }

  private inPalace(row: number, column: number, side: string): boolean {
    if (column < 3 || column > 5) {
      return false;
    }
    return side === 'R' ? row >= 7 && row <= 9 : row >= 0 && row <= 2;
  }

  private generalsFacing(): boolean {
    let red: number = -1;
    let black: number = -1;
    for (let index: number = 0; index < this.board.length; index += 1) {
      if (this.board[index] === 'R帥') {
        red = index;
      } else if (this.board[index] === 'B將') {
        black = index;
      }
    }
    if (red < 0 || black < 0 || red % 9 !== black % 9) {
      return false;
    }
    return this.lineBlockers(red, black) === 0;
  }

  private isGeneralAttacked(side: string): boolean {
    let general: number = -1;
    for (let index: number = 0; index < this.board.length; index += 1) {
      if (this.board[index] === side + (side === 'R' ? '帥' : '將')) {
        general = index;
      }
    }
    if (general < 0) {
      return true;
    }
    const opponent: string = side === 'R' ? 'B' : 'R';
    for (let index: number = 0; index < this.board.length; index += 1) {
      if (this.board[index].indexOf(opponent) === 0 && this.isLegalChineseMove(index, general, opponent)) {
        return true;
      }
    }
    return false;
  }

  private hasLegalChineseMove(side: string): boolean {
    for (let source: number = 0; source < this.board.length; source += 1) {
      if (this.board[source].indexOf(side) !== 0) {
        continue;
      }
      for (let target: number = 0; target < this.board.length; target += 1) {
        if (this.board[target].indexOf(side) === 0 || !this.isLegalChineseMove(source, target, side)) {
          continue;
        }
        const snapshot: string[] = this.board.slice();
        this.board[target] = this.board[source];
        this.board[source] = '';
        const legal: boolean = !this.generalsFacing() && !this.isGeneralAttacked(side);
        this.board = snapshot;
        if (legal) {
          return true;
        }
      }
    }
    return false;
  }

  private chessPositionSignature(nextSide: string): string {
    return nextSide + ':' + this.board.join(',');
  }

  private positionCount(signature: string): number {
    let count: number = 0;
    for (let index: number = 0; index < this.chessPositions.length; index += 1) {
      if (this.chessPositions[index] === signature) {
        count += 1;
      }
    }
    return count;
  }

  private prepareJunqi(players: RoomPlayer[]): void {
    this.board = this.emptyBoard(60);
    const topPositions: number[] = [];
    const bottomPositions: number[] = [];
    for (let index: number = 0; index < 30; index += 1) {
      if (!this.isJunqiCamp(index)) {
        topPositions.push(index);
      }
    }
    for (let index: number = 30; index < 60; index += 1) {
      if (!this.isJunqiCamp(index)) {
        bottomPositions.push(index);
      }
    }
    this.placeJunqiSide('B', topPositions, [1, 3], [0, 1], 5);
    this.placeJunqiSide('R', bottomPositions, [56, 58], [10, 11], 6);
    this.secrets[0] = '你执红方；本局已随机合法布阵，对手军阶已隐藏';
    this.secrets[1] = '你执蓝方；本局已随机合法布阵，对手军阶已隐藏';
    this.prompt = '点击己方棋子后选择目标；行营受保护，铁路可直行，工兵可在铁路转弯';
    this.status = players[0].nickname + ' 执红先行';
  }

  private placeJunqiSide(side: string, positions: number[], headquarters: number[], mineRows: number[],
    frontRow: number): void {
    const available: number[] = positions.slice();
    const flagPosition: number = headquarters[this.random.next(headquarters.length)];
    this.board[flagPosition] = side + '旗';
    this.removeNumber(available, flagPosition);

    const mineCandidates: number[] = [];
    for (let index: number = 0; index < available.length; index += 1) {
      if (mineRows.indexOf(Math.floor(available[index] / 5)) >= 0) {
        mineCandidates.push(available[index]);
      }
    }
    this.shuffleNumbers(mineCandidates);
    for (let index: number = 0; index < 3; index += 1) {
      const position: number = mineCandidates[index];
      this.board[position] = side + '雷';
      this.removeNumber(available, position);
    }

    const bombCandidates: number[] = [];
    for (let index: number = 0; index < available.length; index += 1) {
      if (Math.floor(available[index] / 5) !== frontRow) {
        bombCandidates.push(available[index]);
      }
    }
    this.shuffleNumbers(bombCandidates);
    for (let index: number = 0; index < 2; index += 1) {
      const position: number = bombCandidates[index];
      this.board[position] = side + '炸';
      this.removeNumber(available, position);
    }

    const pieces: string[] = ['司', '军', '师', '师', '旅', '旅', '团', '团', '营', '营', '连', '连',
      '连', '排', '排', '排', '工', '工', '工'];
    this.shuffle(pieces);
    this.shuffleNumbers(available);
    for (let index: number = 0; index < pieces.length; index += 1) {
      this.board[available[index]] = side + pieces[index];
    }
  }

  private removeNumber(values: number[], value: number): void {
    const index: number = values.indexOf(value);
    if (index >= 0) {
      values.splice(index, 1);
    }
  }

  private shuffleNumbers(values: number[]): void {
    for (let index: number = values.length - 1; index > 0; index -= 1) {
      const swapIndex: number = this.random.next(index + 1);
      const value: number = values[index];
      values[index] = values[swapIndex];
      values[swapIndex] = value;
    }
  }

  private moveJunqi(actorIndex: number, target: number, players: RoomPlayer[]): ActionResult {
    if (actorIndex !== this.turnIndex) {
      return new ActionResult(false, '还没轮到你行动');
    }
    const side: string = actorIndex === 0 ? 'R' : 'B';
    if (target < 0 || target >= 60) {
      return new ActionResult(false, '棋盘位置无效');
    }
    if (this.selectedIndex < 0) {
      if (this.board[target].indexOf(side) !== 0) {
        return new ActionResult(false, '请选择自己的棋子');
      }
      const name: string = this.board[target].substring(1);
      if (name === '雷' || name === '旗') {
        return new ActionResult(false, '地雷和军旗不能移动');
      }
      this.selectedIndex = target;
      return new ActionResult(true, '已选择棋子');
    }
    if (this.board[target].indexOf(side) === 0) {
      this.selectedIndex = target;
      return new ActionResult(true, '已改选棋子');
    }
    const source: number = this.selectedIndex;
    const attackerName: string = this.board[source].substring(1);
    if (!this.junqiLegalMovement(source, target, attackerName)) {
      return new ActionResult(false, '该棋子不能沿当前道路或铁路到达目标');
    }
    if (this.board[target].length > 0 && this.isJunqiCamp(target)) {
      return new ActionResult(false, '行营中的棋子不能被攻击');
    }
    const attacker: string = this.board[source];
    const defender: string = this.board[target];
    if (defender.length === 0) {
      this.board[target] = attacker;
      this.board[source] = '';
    } else {
      const result: number = this.junqiFight(attacker.substring(1), defender.substring(1));
      if (defender.substring(1) === '旗') {
        this.finish(players[actorIndex].nickname + ' 夺得军旗获胜');
      } else if (result > 0) {
        this.board[target] = attacker;
        this.board[source] = '';
      } else if (result === 0) {
        this.board[target] = '';
        this.board[source] = '';
      } else {
        this.board[source] = '';
      }
    }
    this.selectedIndex = -1;
    if (!this.isFinished()) {
      this.turnIndex = (this.turnIndex + 1) % 2;
      const opponentSide: string = this.turnIndex === 0 ? 'R' : 'B';
      if (!this.hasMovableJunqi(opponentSide)) {
        this.finish(players[actorIndex].nickname + ' 令对方无棋可走，获得胜利');
      } else {
        this.status = '轮到 ' + players[this.turnIndex].nickname + ' 行动';
      }
    }
    return new ActionResult(true, this.status);
  }

  private junqiAdjacent(source: number, target: number): boolean {
    const sourceRow: number = Math.floor(source / 5);
    const sourceColumn: number = source % 5;
    const targetRow: number = Math.floor(target / 5);
    const targetColumn: number = target % 5;
    return Math.abs(sourceRow - targetRow) + Math.abs(sourceColumn - targetColumn) === 1;
  }

  private junqiLegalMovement(source: number, target: number, piece: string): boolean {
    const sourceRow: number = Math.floor(source / 5);
    const sourceColumn: number = source % 5;
    const targetRow: number = Math.floor(target / 5);
    const targetColumn: number = target % 5;
    if (Math.abs(sourceRow - targetRow) <= 1 && Math.abs(sourceColumn - targetColumn) <= 1 &&
      (this.junqiAdjacent(source, target) || this.isJunqiCamp(source) || this.isJunqiCamp(target))) {
      return true;
    }
    if (!this.isJunqiRail(source) || !this.isJunqiRail(target)) {
      return false;
    }
    if (piece === '工') {
      return this.engineerRailPath(source, target);
    }
    if (sourceRow !== targetRow && sourceColumn !== targetColumn) {
      return false;
    }
    const step: number = sourceRow === targetRow ? (target > source ? 1 : -1) : (target > source ? 5 : -5);
    for (let index: number = source + step; index !== target; index += step) {
      if (!this.isJunqiRail(index) || this.board[index].length > 0) {
        return false;
      }
    }
    return true;
  }

  private isJunqiCamp(index: number): boolean {
    const camps: number[] = [11, 13, 17, 21, 23, 36, 38, 42, 46, 48];
    return camps.indexOf(index) >= 0;
  }

  private isJunqiRail(index: number): boolean {
    const row: number = Math.floor(index / 5);
    const column: number = index % 5;
    return row === 1 || row === 5 || row === 6 || row === 10 ||
      (column === 0 || column === 4) && row >= 1 && row <= 10 ||
      column === 2 && (row >= 1 && row <= 5 || row >= 6 && row <= 10);
  }

  private engineerRailPath(source: number, target: number): boolean {
    const queue: number[] = [source];
    const visited: boolean[] = [];
    for (let index: number = 0; index < 60; index += 1) {
      visited.push(false);
    }
    visited[source] = true;
    while (queue.length > 0) {
      const current: number = queue[0];
      queue.splice(0, 1);
      const row: number = Math.floor(current / 5);
      const column: number = current % 5;
      const neighbors: number[] = [];
      if (row > 0) {
        neighbors.push(current - 5);
      }
      if (row < 11) {
        neighbors.push(current + 5);
      }
      if (column > 0) {
        neighbors.push(current - 1);
      }
      if (column < 4) {
        neighbors.push(current + 1);
      }
      for (let index: number = 0; index < neighbors.length; index += 1) {
        const next: number = neighbors[index];
        if (next === target && this.isJunqiRail(next)) {
          return true;
        }
        if (!visited[next] && this.isJunqiRail(next) && this.board[next].length === 0) {
          visited[next] = true;
          queue.push(next);
        }
      }
    }
    return false;
  }

  private hasMovableJunqi(side: string): boolean {
    for (let index: number = 0; index < this.board.length; index += 1) {
      if (this.board[index].indexOf(side) === 0) {
        const piece: string = this.board[index].substring(1);
        if (piece !== '雷' && piece !== '旗') {
          return true;
        }
      }
    }
    return false;
  }

  private junqiFight(attacker: string, defender: string): number {
    if (attacker === '炸' || defender === '炸') {
      return 0;
    }
    if (defender === '雷') {
      return attacker === '工' ? 1 : -1;
    }
    const order: string[] = ['司', '军', '师', '旅', '团', '营', '连', '排', '工'];
    const attackerRank: number = order.indexOf(attacker);
    const defenderRank: number = order.indexOf(defender);
    if (attackerRank === defenderRank) {
      return 0;
    }
    return attackerRank < defenderRank ? 1 : -1;
  }

  private prepareColorCards(players: RoomPlayer[]): void {
    const colors: string[] = ['红', '黄', '蓝', '绿'];
    for (let colorIndex: number = 0; colorIndex < colors.length; colorIndex += 1) {
      this.deck.push(colors[colorIndex] + '0');
      for (let value: number = 1; value <= 9; value += 1) {
        this.deck.push(colors[colorIndex] + value.toString());
        this.deck.push(colors[colorIndex] + value.toString());
      }
      this.deck.push(colors[colorIndex] + '跳');
      this.deck.push(colors[colorIndex] + '反');
      this.deck.push(colors[colorIndex] + '+2');
    }
    for (let index: number = 0; index < 4; index += 1) {
      this.deck.push('万能变色');
      this.deck.push('万能+4');
    }
    this.shuffle(this.deck);
    for (let cardIndex: number = 0; cardIndex < 7; cardIndex += 1) {
      for (let playerIndex: number = 0; playerIndex < players.length; playerIndex += 1) {
        this.hands[playerIndex].push(this.drawCard());
      }
    }
    let first: string = this.drawCard();
    while (first.indexOf('万能') === 0 && this.deck.length > 0) {
      this.deck.push(first);
      first = this.drawCard();
    }
    this.discard.push(first);
    this.currentColor = first.substring(0, 1);
    this.status = players[0].nickname + ' 先出牌，当前颜色 ' + this.currentColor;
  }

  private playColorCard(actorIndex: number, action: GameAction, players: RoomPlayer[]): ActionResult {
    if (actorIndex !== this.turnIndex) {
      return new ActionResult(false, '还没轮到你出牌');
    }
    if (action.type === 'declare') {
      if (this.hands[actorIndex].length !== 2) {
        return new ActionResult(false, '只有剩两张牌时才能进行末牌提醒');
      }
      this.declaredLastCard[actorIndex] = true;
      return new ActionResult(true, players[actorIndex].nickname + ' 已喊出末牌提醒');
    }
    if (this.pendingDraw > 0) {
      for (let index: number = 0; index < this.pendingDraw; index += 1) {
        this.hands[actorIndex].push(this.drawCard());
      }
      const count: number = this.pendingDraw;
      this.pendingDraw = 0;
      this.advanceDirection(players.length, 1);
      return new ActionResult(true, players[actorIndex].nickname + ' 已摸 ' + count.toString() + ' 张牌');
    }
    if (action.type === 'draw') {
      this.hands[actorIndex].push(this.drawCard());
      this.advanceDirection(players.length, 1);
      this.status = players[actorIndex].nickname + ' 摸一张，轮到 ' + players[this.turnIndex].nickname;
      return new ActionResult(true, this.status);
    }
    if (action.value < 0 || action.value >= this.hands[actorIndex].length) {
      return new ActionResult(false, '请选择有效手牌');
    }
    const card: string = this.hands[actorIndex][action.value];
    const top: string = this.discard[this.discard.length - 1];
    if (card.indexOf('万能') !== 0 && card.substring(0, 1) !== this.currentColor &&
      card.substring(1) !== top.substring(1)) {
      return new ActionResult(false, '颜色或符号与上一张牌不匹配');
    }
    this.hands[actorIndex].splice(action.value, 1);
    this.discard.push(card);
    if (card.indexOf('万能') === 0) {
      this.currentColor = action.first.length > 0 ? action.first : '红';
    } else {
      this.currentColor = card.substring(0, 1);
    }
    let steps: number = 1;
    if (card.indexOf('跳') > 0) {
      steps = 2;
    } else if (card.indexOf('反') > 0) {
      this.direction *= -1;
    } else if (card.indexOf('+2') > 0) {
      this.pendingDraw = 2;
    } else if (card === '万能+4') {
      this.pendingDraw = 4;
    }
    if (this.hands[actorIndex].length === 1 && !this.declaredLastCard[actorIndex]) {
      this.hands[actorIndex].push(this.drawCard());
      this.hands[actorIndex].push(this.drawCard());
      this.history.push(players[actorIndex].nickname + ' 未进行末牌提醒，罚摸两张');
    }
    this.declaredLastCard[actorIndex] = false;
    if (this.hands[actorIndex].length === 0) {
      this.finish(players[actorIndex].nickname + ' 率先出完手牌获胜');
    } else {
      this.advanceDirection(players.length, steps);
      this.status = players[actorIndex].nickname + ' 打出 ' + card + '，当前颜色 ' + this.currentColor;
    }
    return new ActionResult(true, this.status);
  }

  private playLudo(actorIndex: number, action: GameAction, players: RoomPlayer[]): ActionResult {
    if (actorIndex !== this.turnIndex || action.type !== 'roll') {
      return new ActionResult(false, '当前玩家需要掷骰');
    }
    const dice: number = 1 + this.random.next(6);
    const base: number = actorIndex * 4;
    let token: number = action.value;
    if (token < 0 || token > 3) {
      token = 0;
      for (let index: number = 0; index < 4; index += 1) {
        if (this.numbers[base + index] >= 0 && this.numbers[base + index] < 57) {
          token = index;
          break;
        }
      }
    }
    const tokenIndex: number = base + token;
    if (this.numbers[tokenIndex] < 0) {
      if (dice !== 6) {
        this.status = players[actorIndex].nickname + ' 掷出 ' + dice.toString() + '，未能起飞';
      } else {
        this.numbers[tokenIndex] = 0;
        this.status = players[actorIndex].nickname + ' 掷出 6，棋子起飞';
      }
    } else {
      const next: number = this.numbers[tokenIndex] + dice;
      this.numbers[tokenIndex] = next > 57 ? 57 - (next - 57) : next;
      this.status = players[actorIndex].nickname + ' 掷出 ' + dice.toString();
      if (this.numbers[tokenIndex] < 52 && this.numbers[tokenIndex] % 4 === actorIndex) {
        this.numbers[tokenIndex] = Math.min(57, this.numbers[tokenIndex] + 4);
        this.status += '，触发同色跳格';
      }
      if (this.numbers[tokenIndex] === 18) {
        this.numbers[tokenIndex] = 30;
        this.status += '，穿越飞行航线';
      }
      if (this.numbers[tokenIndex] < 52) {
        for (let other: number = 0; other < this.numbers.length; other += 1) {
          if (Math.floor(other / 4) !== actorIndex && this.numbers[other] === this.numbers[tokenIndex]) {
            this.numbers[other] = -1;
          }
        }
      }
    }
    let finished: number = 0;
    for (let index: number = 0; index < 4; index += 1) {
      if (this.numbers[base + index] >= 57) {
        finished += 1;
      }
    }
    if (finished === 4) {
      this.finish(players[actorIndex].nickname + ' 的四枚棋子全部到达终点');
    } else if (dice !== 6) {
      this.turnIndex = (this.turnIndex + 1) % players.length;
    }
    this.refreshLudoBoard(players);
    return new ActionResult(true, this.status);
  }

  private refreshLudoBoard(players: RoomPlayer[]): void {
    this.board = this.emptyBoard(60);
    for (let index: number = 0; index < this.numbers.length; index += 1) {
      const position: number = this.numbers[index];
      if (position >= 0) {
        const playerIndex: number = Math.floor(index / 4);
        const marker: string = (playerIndex + 1).toString();
        const boardIndex: number = Math.min(59, (position + playerIndex * 13) % 52);
        this.board[boardIndex] = this.board[boardIndex] + marker;
      }
    }
  }

  private prepareClimbingCards(players: RoomPlayer[]): void {
    const suits: string[] = ['♠', '♥', '♣', '♦'];
    const ranks: string[] = ['3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A', '2'];
    const deckCount: number = this.definition.id === GameId.GUANDAN ? 2 : 1;
    for (let copy: number = 0; copy < deckCount; copy += 1) {
      for (let suitIndex: number = 0; suitIndex < suits.length; suitIndex += 1) {
        for (let rankIndex: number = 0; rankIndex < ranks.length; rankIndex += 1) {
          this.deck.push(suits[suitIndex] + ranks[rankIndex]);
        }
      }
      this.deck.push('小王');
      this.deck.push('大王');
    }
    this.shuffle(this.deck);
    if (this.definition.id === GameId.LANDLORD) {
      this.landlordBottom = this.deck.slice(51);
    }
    let dealCount: number = this.deck.length;
    if (this.definition.id === GameId.LANDLORD) {
      dealCount = 51;
    }
    for (let index: number = 0; index < dealCount; index += 1) {
      this.hands[index % players.length].push(this.deck[index]);
    }
    if (this.definition.id === GameId.LANDLORD) {
      for (let index: number = 0; index < players.length; index += 1) {
        this.landlordBids.push(-1);
      }
      this.phase = RoomPhase.REVEAL;
      this.status = players[0].nickname + ' 先叫分';
      this.prompt = '可选择不叫、1 分、2 分或 3 分；最高叫分者成为地主';
    } else {
      this.status = players[0].nickname + ' 与 ' + players[2].nickname + ' 为搭档，红桃 2 为逢人配';
      this.deck = [];
    }
  }

  private playClimbingCards(actorIndex: number, action: GameAction, players: RoomPlayer[]): ActionResult {
    if (this.definition.id === GameId.LANDLORD && this.phase === RoomPhase.REVEAL) {
      return this.bidLandlord(actorIndex, action, players);
    }
    if (actorIndex !== this.turnIndex) {
      return new ActionResult(false, '还没轮到你出牌');
    }
    if (action.type === 'pass') {
      if (this.lastPlayCards.length === 0 || this.lastPlayPlayer === actorIndex) {
        return new ActionResult(false, '你是本轮领出玩家，不能不出');
      }
      this.passCount += 1;
      if (this.passCount >= players.length - 1) {
        this.turnIndex = this.lastPlayPlayer;
        this.lastPlayCards = [];
        this.passCount = 0;
        this.status = players[this.turnIndex].nickname + ' 获得新一轮领出权';
      } else {
        this.advanceDirection(players.length, 1);
        this.status = players[actorIndex].nickname + ' 选择不出';
      }
      return new ActionResult(true, this.status);
    }
    const selectedIndexes: number[] = this.selectedCardIndexes(action, this.hands[actorIndex].length);
    if (selectedIndexes.length === 0) {
      return new ActionResult(false, '请至少选择一张有效手牌');
    }
    const cards: string[] = [];
    for (let index: number = 0; index < selectedIndexes.length; index += 1) {
      cards.push(this.hands[actorIndex][selectedIndexes[index]]);
    }
    const pattern: ClimbingPattern = this.climbingPattern(cards);
    if (pattern.type === ClimbingPatternType.INVALID) {
      return new ActionResult(false, '所选牌不构成合法常用牌型');
    }
    if (this.lastPlayCards.length > 0 && this.lastPlayPlayer !== actorIndex) {
      const previous: ClimbingPattern = this.climbingPattern(this.lastPlayCards);
      if (!this.canBeatClimbing(pattern, previous)) {
        return new ActionResult(false, '牌型或点数不能压过上一手');
      }
    }
    selectedIndexes.sort((left: number, right: number): number => right - left);
    for (let index: number = 0; index < selectedIndexes.length; index += 1) {
      this.hands[actorIndex].splice(selectedIndexes[index], 1);
    }
    this.discard = cards.slice();
    this.lastPlayCards = cards.slice();
    this.lastPlayPlayer = actorIndex;
    this.passCount = 0;
    if (pattern.type === ClimbingPatternType.BOMB || pattern.type === ClimbingPatternType.ROCKET) {
      this.multiplier *= 2;
    }
    this.history.push(players[actorIndex].nickname + ' 打出 ' + cards.join(' ') +
      ' · 倍率×' + this.multiplier.toString());
    if (this.hands[actorIndex].length === 0) {
      if (this.definition.id === GameId.GUANDAN) {
        this.scores[actorIndex % 2] += 1;
        this.finish((actorIndex % 2 === 0 ? '甲方搭档' : '乙方搭档') + ' 率先走完并升级');
      } else {
        const landlordWins: boolean = actorIndex === this.landlordIndex;
        this.finish((landlordWins ? '地主方' : '农民方') + ' 获胜 · 结算倍率×' + this.multiplier.toString());
      }
    } else {
      this.advanceDirection(players.length, 1);
      this.status = '上一手 ' + cards.join(' ') + '，轮到 ' + players[this.turnIndex].nickname;
    }
    return new ActionResult(true, this.status);
  }

  private bidLandlord(actorIndex: number, action: GameAction, players: RoomPlayer[]): ActionResult {
    if (actorIndex !== this.turnIndex || action.type !== 'bid' || action.value < 0 || action.value > 3) {
      return new ActionResult(false, '请由当前玩家选择 0–3 分');
    }
    this.landlordBids[actorIndex] = action.value;
    this.history.push(players[actorIndex].nickname + (action.value === 0 ? ' 不叫' :
      ' 叫 ' + action.value.toString() + ' 分'));
    let finishedBidding: boolean = action.value === 3;
    if (!finishedBidding) {
      finishedBidding = true;
      for (let index: number = 0; index < this.landlordBids.length; index += 1) {
        if (this.landlordBids[index] < 0) {
          finishedBidding = false;
        }
      }
    }
    if (!finishedBidding) {
      this.turnIndex = (this.turnIndex + 1) % players.length;
      this.status = '轮到 ' + players[this.turnIndex].nickname + ' 叫分';
      return new ActionResult(true, this.status);
    }
    let highest: number = -1;
    let winnerIndex: number = 0;
    for (let index: number = 0; index < this.landlordBids.length; index += 1) {
      if (this.landlordBids[index] > highest) {
        highest = this.landlordBids[index];
        winnerIndex = index;
      }
    }
    this.landlordIndex = winnerIndex;
    this.multiplier = Math.max(1, highest);
    for (let index: number = 51; index < this.deck.length; index += 1) {
      this.hands[winnerIndex].push(this.deck[index]);
    }
    for (let index: number = 0; index < players.length; index += 1) {
      this.secrets[index] = index === winnerIndex ? '你是地主，底牌已加入手牌' : '你是农民，与另一名农民合作';
    }
    this.deck = [];
    this.turnIndex = winnerIndex;
    this.phase = RoomPhase.PLAYING;
    this.prompt = '选择一张或多张手牌后出牌；连续两家不出则重新领出';
    this.status = players[winnerIndex].nickname + ' 成为地主并先出牌';
    return new ActionResult(true, this.status);
  }

  private selectedCardIndexes(action: GameAction, handSize: number): number[] {
    const result: number[] = [];
    if (action.first.length > 0) {
      const values: string[] = action.first.split(',');
      for (let index: number = 0; index < values.length; index += 1) {
        const value: number = Number(values[index]);
        if (Number.isInteger(value) && value >= 0 && value < handSize && result.indexOf(value) < 0) {
          result.push(value);
        }
      }
    } else if (action.value >= 0 && action.value < handSize) {
      result.push(action.value);
    }
    return result;
  }

  private climbingPattern(cards: string[]): ClimbingPattern {
    const pattern: ClimbingPattern = new ClimbingPattern();
    pattern.length = cards.length;
    if (cards.length === 0) {
      return pattern;
    }
    const counts: number[] = [];
    for (let index: number = 0; index < 15; index += 1) {
      counts.push(0);
    }
    for (let index: number = 0; index < cards.length; index += 1) {
      const rank: number = this.cardRank(cards[index]);
      if (rank < 0) {
        return pattern;
      }
      counts[rank] += 1;
    }
    if (cards.length === 2 && counts[13] === 1 && counts[14] === 1) {
      pattern.type = ClimbingPatternType.ROCKET;
      pattern.mainRank = 14;
      return pattern;
    }
    const uniqueRanks: number[] = this.ranksWithCount(counts, 1);
    const pairRanks: number[] = this.ranksWithCount(counts, 2);
    const tripleRanks: number[] = this.ranksAtLeast(counts, 3, 12);
    const bombRanks: number[] = this.ranksWithExactCount(counts, cards.length);
    if (cards.length >= 4 && bombRanks.length === 1) {
      pattern.type = ClimbingPatternType.BOMB;
      pattern.mainRank = bombRanks[0];
      return pattern;
    }
    if (cards.length === 1) {
      pattern.type = ClimbingPatternType.SINGLE;
      pattern.mainRank = uniqueRanks[0];
      return pattern;
    }
    if (cards.length === 2 && pairRanks.length === 1) {
      pattern.type = ClimbingPatternType.PAIR;
      pattern.mainRank = pairRanks[0];
      return pattern;
    }
    if (cards.length === 3 && tripleRanks.length === 1) {
      pattern.type = ClimbingPatternType.TRIPLE;
      pattern.mainRank = tripleRanks[0];
      return pattern;
    }
    if (cards.length === 4 && tripleRanks.length === 1) {
      pattern.type = ClimbingPatternType.TRIPLE_SINGLE;
      pattern.mainRank = tripleRanks[0];
      return pattern;
    }
    if (cards.length === 5 && tripleRanks.length === 1 && pairRanks.length === 1) {
      pattern.type = ClimbingPatternType.TRIPLE_PAIR;
      pattern.mainRank = tripleRanks[0];
      return pattern;
    }
    if (cards.length >= 5 && uniqueRanks.length === cards.length && this.consecutive(uniqueRanks) &&
      uniqueRanks[uniqueRanks.length - 1] <= 11) {
      pattern.type = ClimbingPatternType.STRAIGHT;
      pattern.mainRank = uniqueRanks[uniqueRanks.length - 1];
      return pattern;
    }
    if (cards.length >= 6 && cards.length % 2 === 0 && pairRanks.length * 2 === cards.length &&
      this.consecutive(pairRanks) && pairRanks[pairRanks.length - 1] <= 11) {
      pattern.type = ClimbingPatternType.PAIR_STRAIGHT;
      pattern.mainRank = pairRanks[pairRanks.length - 1];
      return pattern;
    }
    if (tripleRanks.length >= 2 && this.consecutive(tripleRanks)) {
      const tripleCount: number = tripleRanks.length;
      pattern.tripleCount = tripleCount;
      pattern.mainRank = tripleRanks[tripleRanks.length - 1];
      if (cards.length === tripleCount * 3) {
        pattern.type = ClimbingPatternType.AIRPLANE;
        return pattern;
      }
      if (cards.length === tripleCount * 4) {
        pattern.type = ClimbingPatternType.AIRPLANE_SINGLE;
        return pattern;
      }
      if (cards.length === tripleCount * 5 && this.airplanePairWings(counts, tripleRanks)) {
        pattern.type = ClimbingPatternType.AIRPLANE_PAIR;
        return pattern;
      }
    }
    const fourRanks: number[] = this.ranksAtLeast(counts, 4, 15);
    if (fourRanks.length === 1 && cards.length === 6) {
      pattern.type = ClimbingPatternType.FOUR_TWO;
      pattern.mainRank = fourRanks[0];
      return pattern;
    }
    if (fourRanks.length === 1 && cards.length === 8 && this.fourWithTwoPairs(counts, fourRanks[0])) {
      pattern.type = ClimbingPatternType.FOUR_TWO_PAIR;
      pattern.mainRank = fourRanks[0];
      return pattern;
    }
    return pattern;
  }

  private canBeatClimbing(next: ClimbingPattern, previous: ClimbingPattern): boolean {
    if (next.type === ClimbingPatternType.ROCKET) {
      return true;
    }
    if (previous.type === ClimbingPatternType.ROCKET) {
      return false;
    }
    if (next.type === ClimbingPatternType.BOMB && previous.type !== ClimbingPatternType.BOMB) {
      return true;
    }
    if (next.type !== previous.type) {
      return false;
    }
    if (next.type === ClimbingPatternType.BOMB && next.length !== previous.length) {
      return next.length > previous.length;
    }
    return next.length === previous.length && next.tripleCount === previous.tripleCount &&
      next.mainRank > previous.mainRank;
  }

  private cardRank(card: string): number {
    if (card === '小王') {
      return 13;
    }
    if (card === '大王') {
      return 14;
    }
    const ranks: string[] = ['3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A', '2'];
    return ranks.indexOf(card.substring(1));
  }

  private ranksWithCount(counts: number[], count: number): number[] {
    return this.ranksWithExactCount(counts, count);
  }

  private ranksWithExactCount(counts: number[], count: number): number[] {
    const result: number[] = [];
    for (let index: number = 0; index < counts.length; index += 1) {
      if (counts[index] === count) {
        result.push(index);
      }
    }
    return result;
  }

  private ranksAtLeast(counts: number[], count: number, upperExclusive: number): number[] {
    const result: number[] = [];
    for (let index: number = 0; index < Math.min(counts.length, upperExclusive); index += 1) {
      if (counts[index] >= count) {
        result.push(index);
      }
    }
    return result;
  }

  private consecutive(ranks: number[]): boolean {
    for (let index: number = 1; index < ranks.length; index += 1) {
      if (ranks[index] !== ranks[index - 1] + 1) {
        return false;
      }
    }
    return ranks.length > 0;
  }

  private airplanePairWings(counts: number[], tripleRanks: number[]): boolean {
    let pairCount: number = 0;
    for (let index: number = 0; index < counts.length; index += 1) {
      let rest: number = counts[index];
      if (tripleRanks.indexOf(index) >= 0) {
        rest -= 3;
      }
      if (rest === 2) {
        pairCount += 1;
      } else if (rest !== 0) {
        return false;
      }
    }
    return pairCount === tripleRanks.length;
  }

  private fourWithTwoPairs(counts: number[], fourRank: number): boolean {
    let pairCount: number = 0;
    for (let index: number = 0; index < counts.length; index += 1) {
      const rest: number = index === fourRank ? counts[index] - 4 : counts[index];
      if (rest === 2) {
        pairCount += 1;
      } else if (rest !== 0) {
        return false;
      }
    }
    return pairCount === 2;
  }

  private prepareMahjong(players: RoomPlayer[]): void {
    const suits: string[] = ['万', '筒', '条'];
    for (let suitIndex: number = 0; suitIndex < suits.length; suitIndex += 1) {
      for (let value: number = 1; value <= 9; value += 1) {
        for (let copy: number = 0; copy < 4; copy += 1) {
          this.deck.push(value.toString() + suits[suitIndex]);
        }
      }
    }
    this.shuffle(this.deck);
    for (let count: number = 0; count < 13; count += 1) {
      for (let playerIndex: number = 0; playerIndex < players.length; playerIndex += 1) {
        this.hands[playerIndex].push(this.drawCard());
      }
    }
    for (let index: number = 0; index < players.length; index += 1) {
      this.mahjongMissing.push('');
      this.mahjongExchangeIndexes.push([]);
      this.secrets[index] = '换三张：请选择三张同花色手牌';
    }
    this.phase = RoomPhase.REVEAL;
    this.mahjongStage = 'exchange';
    this.turnIndex = 0;
    this.prompt = '四名玩家依次选择三张同花色牌；系统统一按本局方向交换';
    this.status = players[0].nickname + ' 请选择换出的三张牌';
  }

  private playMahjong(actorIndex: number, action: GameAction, players: RoomPlayer[]): ActionResult {
    if (this.mahjongStage === 'exchange') {
      return this.exchangeMahjong(actorIndex, action, players);
    }
    if (this.mahjongStage === 'missing') {
      return this.chooseMahjongMissing(actorIndex, action, players);
    }
    if (actorIndex !== this.turnIndex) {
      return new ActionResult(false, '还没轮到你出牌');
    }
    if (action.type === 'win' && this.isMahjongWin(this.hands[actorIndex])) {
      this.alive[actorIndex] = false;
      this.scores[actorIndex] += 2;
      this.history.push(players[actorIndex].nickname + ' 胡牌');
      if (this.aliveCount() <= 1 || this.deck.length === 0) {
        this.finish('血战结束，最高分玩家获胜');
      } else {
        this.nextAliveTurn(players);
        this.hands[this.turnIndex].push(this.drawCard());
        this.status = players[actorIndex].nickname + ' 胡牌，血战继续';
      }
      return new ActionResult(true, this.status);
    }
    if (action.value < 0 || action.value >= this.hands[actorIndex].length) {
      return new ActionResult(false, '请选择要打出的牌');
    }
    const tile: string = this.hands[actorIndex][action.value];
    const missing: string = this.mahjongMissing[actorIndex];
    if (tile.indexOf(missing) < 0 && this.hasMahjongSuit(this.hands[actorIndex], missing)) {
      return new ActionResult(false, '手中仍有定缺牌，必须优先打出 ' + missing);
    }
    this.hands[actorIndex].splice(action.value, 1);
    this.discard.push(tile);
    this.playerDiscards[actorIndex].push(tile);
    this.nextAliveTurn(players);
    if (this.deck.length === 0) {
      this.finish('牌墙耗尽，本局流局');
    } else {
      this.hands[this.turnIndex].push(this.drawCard());
      this.status = players[actorIndex].nickname + ' 打出 ' + tile + '，轮到 ' + players[this.turnIndex].nickname;
    }
    return new ActionResult(true, this.status);
  }

  private exchangeMahjong(actorIndex: number, action: GameAction, players: RoomPlayer[]): ActionResult {
    if (actorIndex !== this.turnIndex || action.type !== 'exchange') {
      return new ActionResult(false, '请由当前玩家选择换三张');
    }
    const indexes: number[] = this.selectedCardIndexes(action, this.hands[actorIndex].length);
    if (indexes.length !== 3) {
      return new ActionResult(false, '必须恰好选择三张牌');
    }
    const suit: string = this.hands[actorIndex][indexes[0]].substring(1);
    for (let index: number = 1; index < indexes.length; index += 1) {
      if (this.hands[actorIndex][indexes[index]].substring(1) !== suit) {
        return new ActionResult(false, '换出的三张牌必须同花色');
      }
    }
    this.mahjongExchangeIndexes[actorIndex] = indexes.slice();
    if (actorIndex < players.length - 1) {
      this.turnIndex += 1;
      this.status = players[this.turnIndex].nickname + ' 请选择换出的三张牌';
      return new ActionResult(true, this.status);
    }
    const exchanged: string[][] = [];
    for (let playerIndex: number = 0; playerIndex < players.length; playerIndex += 1) {
      const selected: number[] = this.mahjongExchangeIndexes[playerIndex].slice();
      selected.sort((left: number, right: number): number => right - left);
      const tiles: string[] = [];
      for (let index: number = 0; index < selected.length; index += 1) {
        tiles.push(this.hands[playerIndex][selected[index]]);
        this.hands[playerIndex].splice(selected[index], 1);
      }
      exchanged.push(tiles);
    }
    const offsetOptions: number[] = [1, 2, 3];
    const offset: number = offsetOptions[this.random.next(offsetOptions.length)];
    for (let playerIndex: number = 0; playerIndex < players.length; playerIndex += 1) {
      const sourceIndex: number = (playerIndex - offset + players.length) % players.length;
      this.hands[playerIndex] = this.hands[playerIndex].concat(exchanged[sourceIndex]);
      this.secrets[playerIndex] = '请选择定缺花色';
    }
    this.mahjongStage = 'missing';
    this.turnIndex = 0;
    this.prompt = '依次选择万、筒或条作为定缺；有缺门牌时必须优先打出';
    this.status = players[0].nickname + ' 请选择定缺花色';
    return new ActionResult(true, this.status);
  }

  private chooseMahjongMissing(actorIndex: number, action: GameAction, players: RoomPlayer[]): ActionResult {
    if (actorIndex !== this.turnIndex || action.type !== 'missing' ||
      action.first !== '万' && action.first !== '筒' && action.first !== '条') {
      return new ActionResult(false, '请选择万、筒或条作为定缺');
    }
    this.mahjongMissing[actorIndex] = action.first;
    this.secrets[actorIndex] = '定缺：' + action.first + '；请优先打缺门牌';
    if (actorIndex < players.length - 1) {
      this.turnIndex += 1;
      this.status = players[this.turnIndex].nickname + ' 请选择定缺花色';
      return new ActionResult(true, this.status);
    }
    this.mahjongStage = 'play';
    this.phase = RoomPhase.PLAYING;
    this.turnIndex = 0;
    this.hands[0].push(this.drawCard());
    this.prompt = '四川血战：无吃，有碰杠胡；当前实现按固定基础番结算';
    this.status = players[0].nickname + ' 为庄家，请先打牌';
    return new ActionResult(true, this.status);
  }

  private hasMahjongSuit(hand: string[], suit: string): boolean {
    for (let index: number = 0; index < hand.length; index += 1) {
      if (hand[index].indexOf(suit) >= 0) {
        return true;
      }
    }
    return false;
  }

  private isMahjongWin(hand: string[]): boolean {
    if (hand.length % 3 !== 2) {
      return false;
    }
    const sorted: string[] = hand.slice();
    sorted.sort();
    for (let index: number = 0; index + 1 < sorted.length; index += 1) {
      if (sorted[index] === sorted[index + 1]) {
        const rest: string[] = sorted.slice();
        rest.splice(index, 2);
        if (this.removeMahjongMelds(rest)) {
          return true;
        }
      }
    }
    return false;
  }

  private removeMahjongMelds(tiles: string[]): boolean {
    if (tiles.length === 0) {
      return true;
    }
    const first: string = tiles[0];
    if (tiles.length >= 3 && tiles[1] === first && tiles[2] === first) {
      const tripletRest: string[] = tiles.slice(3);
      if (this.removeMahjongMelds(tripletRest)) {
        return true;
      }
    }
    const value: number = Number(first.substring(0, 1));
    const suit: string = first.substring(1);
    if (value > 0 && value <= 7) {
      const second: string = (value + 1).toString() + suit;
      const third: string = (value + 2).toString() + suit;
      const secondIndex: number = tiles.indexOf(second);
      const thirdIndex: number = tiles.indexOf(third);
      if (secondIndex > 0 && thirdIndex > 0) {
        const sequenceRest: string[] = tiles.slice();
        sequenceRest.splice(Math.max(secondIndex, thirdIndex), 1);
        sequenceRest.splice(Math.min(secondIndex, thirdIndex), 1);
        sequenceRest.splice(0, 1);
        if (this.removeMahjongMelds(sequenceRest)) {
          return true;
        }
      }
    }
    return false;
  }

  private playDrawGuess(actorIndex: number, action: GameAction, players: RoomPlayer[]): ActionResult {
    if (action.type === 'aiComplete' && actorIndex === this.turnIndex) {
      this.scores[actorIndex] += 1;
      this.history.push(players[actorIndex].nickname + ' 完成了 AI 示意画');
      this.advanceDrawGuessRound(players);
      return new ActionResult(true, this.status);
    }
    if (action.type === 'aiGuess' && actorIndex !== this.turnIndex) {
      action.first = this.drawWord;
      action.type = 'guess';
    }
    if (action.type === 'guess') {
      if (actorIndex === this.turnIndex) {
        return new ActionResult(false, '画家不能猜自己的题目');
      }
      if (action.first.trim() === this.drawWord) {
        this.scores[actorIndex] += 2;
        this.scores[this.turnIndex] += 1;
        this.history.push(players[actorIndex].nickname + ' 猜中：' + this.drawWord);
        this.advanceDrawGuessRound(players);
        return new ActionResult(true, this.status);
      }
      return new ActionResult(false, '答案不正确，再想一想');
    }
    if (action.type === 'stroke') {
      this.history.push(players[actorIndex].nickname + ' 更新了画板');
      return new ActionResult(true, '画板已同步');
    }
    return new ActionResult(false, '请选择画画或猜词');
  }

  private advanceDrawGuessRound(players: RoomPlayer[]): void {
    this.round += 1;
    if (this.round > players.length * 2) {
      this.finish('画猜结束，查看最终积分');
      return;
    }
    this.turnIndex = (this.turnIndex + 1) % players.length;
    this.drawWord = this.randomPrompt('draw');
    for (let index: number = 0; index < this.secrets.length; index += 1) {
      this.secrets[index] = index === this.turnIndex ? '本轮题目：' + this.drawWord : '';
    }
    this.status = players[this.turnIndex].nickname + ' 是本轮画家';
  }

  private preparePromptRound(players: RoomPlayer[]): void {
    const promptType: string = this.definition.id === GameId.CHARADES ? 'charades' : 'truth';
    const text: string = this.randomPrompt(promptType);
    this.secrets[0] = text;
    this.prompt = this.definition.id === GameId.CHARADES ? '表演者不可说出题面文字' : '完成挑战后由同伴确认';
    this.status = players[0].nickname + ' 开始本轮挑战';
  }

  private playPromptGame(actorIndex: number, action: GameAction, players: RoomPlayer[]): ActionResult {
    if (actorIndex !== this.turnIndex || action.type !== 'complete') {
      return new ActionResult(false, '当前挑战者完成后才能继续');
    }
    this.scores[actorIndex] += 1;
    this.round += 1;
    if (this.round > players.length * 2) {
      this.finish(this.definition.title + ' 已完成全部回合');
    } else {
      this.turnIndex = (this.turnIndex + 1) % players.length;
      const promptType: string = this.definition.id === GameId.CHARADES ? 'charades' : 'truth';
      for (let index: number = 0; index < this.secrets.length; index += 1) {
        this.secrets[index] = index === this.turnIndex ? this.randomPrompt(promptType) : '';
      }
      this.status = '轮到 ' + players[this.turnIndex].nickname + ' 挑战';
    }
    return new ActionResult(true, this.status);
  }

  private playNumberBomb(actorIndex: number, action: GameAction, players: RoomPlayer[]): ActionResult {
    if (actorIndex !== this.turnIndex || action.type !== 'guess') {
      return new ActionResult(false, '还没轮到你猜数字');
    }
    const guess: number = action.value;
    if (guess <= this.numberLow || guess >= this.numberHigh) {
      return new ActionResult(false, '请输入 ' + this.numberLow.toString() + ' 与 ' + this.numberHigh.toString() + ' 之间的数字');
    }
    if (guess === this.numberBomb) {
      this.scores[actorIndex] -= 1;
      this.history.push(players[actorIndex].nickname + ' 猜中炸弹 ' + guess.toString());
      this.round += 1;
      if (this.round > players.length * 2) {
        this.finish('数字炸弹已完成全部回合');
      } else {
        this.numberLow = 1;
        this.numberHigh = 100;
        this.numberBomb = 1 + this.random.next(100);
        this.turnIndex = (this.turnIndex + 1) % players.length;
      }
    } else {
      if (guess < this.numberBomb) {
        this.numberLow = guess;
      } else {
        this.numberHigh = guess;
      }
      this.turnIndex = (this.turnIndex + 1) % players.length;
    }
    this.prompt = '范围 ' + this.numberLow.toString() + '–' + this.numberHigh.toString();
    this.status = '轮到 ' + players[this.turnIndex].nickname + ' 猜数字';
    return new ActionResult(true, this.status);
  }

  private buildChoices(playerIndex: number, players: RoomPlayer[]): GameChoice[] {
    const choices: GameChoice[] = [];
    if (playerIndex < 0 || this.phase === RoomPhase.FINISHED) {
      return choices;
    }
    if (this.phase === RoomPhase.VOTING) {
      for (let index: number = 0; index < players.length; index += 1) {
        if (this.alive[index] && index !== playerIndex) {
          choices.push(new GameChoice('vote-' + index.toString(), '投给 ' + players[index].nickname, 'vote', index));
        }
      }
      return choices;
    }
    if (this.definition.id === GameId.WEREWOLF && this.phase === RoomPhase.PLAYING) {
      if (playerIndex !== this.turnIndex) {
        return choices;
      }
      for (let index: number = 0; index < players.length; index += 1) {
        if (!this.alive[index]) {
          continue;
        }
        if (this.werewolfStage === 'wolf' && this.werewolfRoles[index] !== '狼人') {
          choices.push(new GameChoice('wolf-' + index.toString(), '袭击 ' + players[index].nickname,
            'wolfKill', index));
        } else if (this.werewolfStage === 'seer' && index !== playerIndex) {
          choices.push(new GameChoice('seer-' + index.toString(), '查验 ' + players[index].nickname,
            'seerInspect', index));
        } else if (this.werewolfStage === 'guard') {
          choices.push(new GameChoice('guard-' + index.toString(), '守护 ' + players[index].nickname,
            'guard', index));
        } else if (this.werewolfStage === 'witch' && this.witchPoisonAvailable && index !== playerIndex) {
          choices.push(new GameChoice('poison-' + index.toString(), '毒杀 ' + players[index].nickname,
            'witchPoison', index));
        } else if (this.werewolfStage === 'hunter' && index !== playerIndex) {
          choices.push(new GameChoice('shoot-' + index.toString(), '带走 ' + players[index].nickname,
            'hunterShoot', index));
        }
      }
      if (this.werewolfStage === 'witch') {
        if (this.witchSaveAvailable && this.werewolfNightTarget >= 0) {
          choices.push(new GameChoice('save', '使用解药', 'witchSave'));
        }
        choices.push(new GameChoice('witch-skip', '今晚不用药', 'witchSkip'));
      } else if (this.werewolfStage === 'hunter') {
        choices.push(new GameChoice('hunter-skip', '不开枪', 'hunterSkip'));
      }
      return choices;
    }
    if (this.definition.id === GameId.SICHUAN_MAHJONG && this.phase === RoomPhase.REVEAL) {
      if (this.mahjongStage === 'missing' && playerIndex === this.turnIndex) {
        choices.push(new GameChoice('missing-wan', '定缺 万', 'missing', -1, '万'));
        choices.push(new GameChoice('missing-tong', '定缺 筒', 'missing', -1, '筒'));
        choices.push(new GameChoice('missing-tiao', '定缺 条', 'missing', -1, '条'));
      }
      return choices;
    }
    if (this.definition.id === GameId.LANDLORD && this.phase === RoomPhase.REVEAL) {
      if (playerIndex === this.turnIndex) {
        choices.push(new GameChoice('bid-0', '不叫', 'bid', 0));
        choices.push(new GameChoice('bid-1', '1 分', 'bid', 1));
        choices.push(new GameChoice('bid-2', '2 分', 'bid', 2));
        choices.push(new GameChoice('bid-3', '3 分', 'bid', 3));
      }
      return choices;
    }
    if (this.definition.id === GameId.UNDERCOVER) {
      choices.push(new GameChoice('next', '完成描述', 'next'));
    } else if (this.definition.id === GameId.COLOR_CLASH || this.definition.id === GameId.LANDLORD ||
      this.definition.id === GameId.GUANDAN || this.definition.id === GameId.SICHUAN_MAHJONG) {
      if (this.definition.id !== GameId.LANDLORD && this.definition.id !== GameId.GUANDAN) {
        for (let index: number = 0; index < this.hands[playerIndex].length; index += 1) {
          choices.push(new GameChoice('card-' + index.toString(), this.hands[playerIndex][index], 'play', index));
        }
      }
      if (this.definition.id === GameId.COLOR_CLASH) {
        if (this.hands[playerIndex].length === 2 && playerIndex === this.turnIndex) {
          choices.push(new GameChoice('declare-last', '末牌！', 'declare'));
        }
        choices.push(new GameChoice('draw', '摸一张', 'draw'));
      } else if (this.definition.id === GameId.LANDLORD || this.definition.id === GameId.GUANDAN) {
        choices.push(new GameChoice('pass', '不要', 'pass'));
      } else if (this.isMahjongWin(this.hands[playerIndex])) {
        choices.push(new GameChoice('win', '胡牌', 'win'));
      }
    } else if (this.definition.id === GameId.LUDO) {
      for (let index: number = 0; index < 4; index += 1) {
        choices.push(new GameChoice('roll-' + index.toString(), '掷骰移动棋子 ' + (index + 1).toString(), 'roll', index));
      }
    } else if (this.definition.id === GameId.CHARADES || this.definition.id === GameId.TRUTH_DARE) {
      choices.push(new GameChoice('complete', '完成挑战', 'complete'));
    }
    return choices;
  }

  private maskedBoard(playerId: string, players: RoomPlayer[]): string[] {
    const result: string[] = this.board.slice();
    if (this.definition.id !== GameId.JUNQI) {
      for (let index: number = 0; index < result.length; index += 1) {
        if (result[index].length > 1 && this.definition.id === GameId.CHINESE_CHESS) {
          result[index] = result[index].substring(1);
        }
      }
      return result;
    }
    const playerIndex: number = this.findPlayer(players, playerId);
    const ownSide: string = playerIndex === 0 ? 'R' : 'B';
    for (let index: number = 0; index < result.length; index += 1) {
      if (result[index].length > 1) {
        result[index] = result[index].indexOf(ownSide) === 0 ? result[index].substring(1) : '◆';
      }
    }
    return result;
  }

  private boardOwners(): string[] {
    const result: string[] = [];
    for (let index: number = 0; index < this.board.length; index += 1) {
      const cell: string = this.board[index];
      if ((this.definition.id === GameId.JUNQI || this.definition.id === GameId.CHINESE_CHESS) &&
        cell.length > 1) {
        result.push(cell.substring(0, 1));
      } else {
        result.push('');
      }
    }
    return result;
  }

  private canPlayerAct(playerIndex: number): boolean {
    if (this.phase === RoomPhase.VOTING) {
      return this.alive[playerIndex] && this.votes[playerIndex] < 0;
    }
    if (this.definition.id === GameId.DRAW_GUESS) {
      return true;
    }
    return playerIndex === this.turnIndex && this.alive[playerIndex];
  }

  private boardColumns(): number {
    if (this.definition.id === GameId.GOMOKU) {
      return 15;
    }
    if (this.definition.id === GameId.REVERSI) {
      return 8;
    }
    if (this.definition.id === GameId.CHINESE_CHESS) {
      return 9;
    }
    if (this.definition.id === GameId.JUNQI) {
      return 5;
    }
    if (this.definition.id === GameId.LUDO) {
      return 10;
    }
    return 1;
  }

  private randomPrompt(type: string): string {
    const draw: string[] = BuiltInContent.drawWords();
    const charades: string[] = BuiltInContent.charadesWords();
    const truth: string[] = BuiltInContent.truthQuestions().concat(BuiltInContent.dareChallenges());
    if (type === 'draw') {
      return draw[this.random.next(draw.length)];
    }
    if (type === 'charades') {
      return charades[this.random.next(charades.length)];
    }
    return truth[this.random.next(truth.length)];
  }

  private drawCard(): string {
    if (this.deck.length === 0 && this.discard.length > 1) {
      const top: string = this.discard[this.discard.length - 1];
      this.deck = this.discard.slice(0, this.discard.length - 1);
      this.discard = [top];
      this.shuffle(this.deck);
    }
    if (this.deck.length === 0) {
      return '空牌';
    }
    const card: string = this.deck[this.deck.length - 1];
    this.deck.pop();
    return card;
  }

  private shuffle(values: string[]): void {
    for (let index: number = values.length - 1; index > 0; index -= 1) {
      const swapIndex: number = this.random.next(index + 1);
      const value: string = values[index];
      values[index] = values[swapIndex];
      values[swapIndex] = value;
    }
  }

  private emptyBoard(size: number): string[] {
    const values: string[] = [];
    for (let index: number = 0; index < size; index += 1) {
      values.push('');
    }
    return values;
  }

  private boardFull(): boolean {
    for (let index: number = 0; index < this.board.length; index += 1) {
      if (this.board[index].length === 0) {
        return false;
      }
    }
    return true;
  }

  private hasLine(index: number, symbol: string, rows: number, columns: number, count: number): boolean {
    const directions: number[][] = [[0, 1], [1, 0], [1, 1], [1, -1]];
    const row: number = Math.floor(index / columns);
    const column: number = index % columns;
    for (let directionIndex: number = 0; directionIndex < directions.length; directionIndex += 1) {
      let total: number = 1;
      for (let sign: number = -1; sign <= 1; sign += 2) {
        let nextRow: number = row + directions[directionIndex][0] * sign;
        let nextColumn: number = column + directions[directionIndex][1] * sign;
        while (nextRow >= 0 && nextRow < rows && nextColumn >= 0 && nextColumn < columns &&
          this.board[nextRow * columns + nextColumn] === symbol) {
          total += 1;
          nextRow += directions[directionIndex][0] * sign;
          nextColumn += directions[directionIndex][1] * sign;
        }
      }
      if (total >= count) {
        return true;
      }
    }
    return false;
  }

  private advanceDirection(playerCount: number, steps: number): void {
    for (let index: number = 0; index < steps; index += 1) {
      this.turnIndex = (this.turnIndex + this.direction + playerCount) % playerCount;
    }
  }

  private nextAliveTurn(players: RoomPlayer[]): void {
    for (let count: number = 0; count < players.length; count += 1) {
      this.turnIndex = (this.turnIndex + 1) % players.length;
      if (this.alive[this.turnIndex]) {
        return;
      }
    }
  }

  private findPlayer(players: RoomPlayer[], id: string): number {
    for (let index: number = 0; index < players.length; index += 1) {
      if (players[index].id === id) {
        return index;
      }
    }
    return -1;
  }

  private resetVotes(): void {
    for (let index: number = 0; index < this.votes.length; index += 1) {
      this.votes[index] = -1;
    }
  }

  private allAliveVoted(): boolean {
    for (let index: number = 0; index < this.alive.length; index += 1) {
      if (this.alive[index] && this.votes[index] < 0) {
        return false;
      }
    }
    return true;
  }

  private voteWinner(playerCount: number): number {
    const counts: number[] = [];
    for (let index: number = 0; index < playerCount; index += 1) {
      counts.push(0);
    }
    for (let index: number = 0; index < this.votes.length; index += 1) {
      if (this.votes[index] >= 0) {
        counts[this.votes[index]] += 1;
      }
    }
    let winnerIndex: number = -1;
    let highest: number = 0;
    let tied: boolean = false;
    for (let index: number = 0; index < counts.length; index += 1) {
      if (counts[index] > highest) {
        highest = counts[index];
        winnerIndex = index;
        tied = false;
      } else if (counts[index] === highest && highest > 0) {
        tied = true;
      }
    }
    return tied ? -1 : winnerIndex;
  }

  private aliveCount(): number {
    let count: number = 0;
    for (let index: number = 0; index < this.alive.length; index += 1) {
      if (this.alive[index]) {
        count += 1;
      }
    }
    return count;
  }

  private firstAlive(): number {
    for (let index: number = 0; index < this.alive.length; index += 1) {
      if (this.alive[index]) {
        return index;
      }
    }
    return 0;
  }

  private finish(message: string): void {
    this.phase = RoomPhase.FINISHED;
    this.winner = message;
    this.status = message;
    this.history.push(message);
  }
}
