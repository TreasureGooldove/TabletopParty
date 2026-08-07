export enum GameId {
  UNDERCOVER = 'undercover',
  LANDLORD = 'landlord',
  CHINESE_CHESS = 'chineseChess',
  JUNQI = 'junqi',
  WEREWOLF = 'werewolf',
  COLOR_CLASH = 'colorClash',
  GOMOKU = 'gomoku',
  REVERSI = 'reversi',
  LUDO = 'ludo',
  SICHUAN_MAHJONG = 'sichuanMahjong',
  GUANDAN = 'guandan',
  DRAW_GUESS = 'drawGuess',
  CHARADES = 'charades',
  NUMBER_BOMB = 'numberBomb',
  TRUTH_DARE = 'truthDare'
}

export enum GameCategory {
  BOARD = 'board',
  CARD = 'card',
  DEDUCTION = 'deduction',
  PARTY = 'party'
}

export enum RoomPhase {
  LOBBY = 'lobby',
  REVEAL = 'reveal',
  PLAYING = 'playing',
  VOTING = 'voting',
  FINISHED = 'finished'
}

export enum PlayerKind {
  HUMAN = 'human',
  AI_EASY = 'aiEasy',
  AI_NORMAL = 'aiNormal'
}

export enum TransportKind {
  HOT_SEAT = 'hotSeat',
  NEARLINK = 'nearLink',
  LAN = 'lan',
  KNOCK_SHARE = 'knockShare',
  SYSTEM_SHARE = 'systemShare'
}

export class GameDefinition {
  public id: GameId;
  public title: string;
  public category: GameCategory;
  public summary: string;
  public rules: string;
  public minPlayers: number;
  public maxPlayers: number;
  public accent: string;
  public iconText: string;
  public supportsAi: boolean;
  public featured: boolean;

  constructor(id: GameId, title: string, category: GameCategory, summary: string, rules: string,
    minPlayers: number, maxPlayers: number, accent: string, iconText: string,
    supportsAi: boolean = false, featured: boolean = true) {
    this.id = id;
    this.title = title;
    this.category = category;
    this.summary = summary;
    this.rules = rules;
    this.minPlayers = minPlayers;
    this.maxPlayers = maxPlayers;
    this.accent = accent;
    this.iconText = iconText;
    this.supportsAi = supportsAi;
    this.featured = featured;
  }
}

export class RoomPlayer {
  public id: string;
  public nickname: string;
  public seat: number;
  public host: boolean;
  public kind: PlayerKind;

  constructor(id: string, nickname: string, seat: number, host: boolean,
    kind: PlayerKind = PlayerKind.HUMAN) {
    this.id = id;
    this.nickname = nickname;
    this.seat = seat;
    this.host = host;
    this.kind = kind;
  }
}

export class GameAction {
  public type: string;
  public actorId: string;
  public first: string;
  public second: string;
  public value: number;

  constructor(type: string, actorId: string, first: string = '', second: string = '', value: number = -1) {
    this.type = type;
    this.actorId = actorId;
    this.first = first;
    this.second = second;
    this.value = value;
  }
}

export class ActionResult {
  public success: boolean;
  public message: string;

  constructor(success: boolean, message: string) {
    this.success = success;
    this.message = message;
  }
}

export class GameChoice {
  public id: string;
  public label: string;
  public actionType: string;
  public value: number;
  public first: string;

  constructor(id: string, label: string, actionType: string, value: number = -1, first: string = '') {
    this.id = id;
    this.label = label;
    this.actionType = actionType;
    this.value = value;
    this.first = first;
  }
}

export class GameView {
  public gameId: GameId = GameId.UNDERCOVER;
  public phase: RoomPhase = RoomPhase.LOBBY;
  public title: string = '';
  public status: string = '';
  public prompt: string = '';
  public privateText: string = '';
  public winner: string = '';
  public currentPlayerId: string = '';
  public currentPlayerName: string = '';
  public round: number = 1;
  public board: string[] = [];
  public boardOwners: string[] = [];
  public selectedBoardIndex: number = -1;
  public hand: string[] = [];
  public handCounts: number[] = [];
  public tableCards: string[] = [];
  public bottomCards: string[] = [];
  public landlordSeat: number = -1;
  public multiplier: number = 1;
  public remainingCards: number = 0;
  public playerDiscards: string[][] = [];
  public missingSuits: string[] = [];
  public gameStage: string = '';
  public history: string[] = [];
  public choices: GameChoice[] = [];
  public scores: number[] = [];
  public alive: boolean[] = [];
  public columns: number = 1;
  public canAct: boolean = false;
}

export interface GamePlugin {
  getDefinition(): GameDefinition;
  start(players: RoomPlayer[], seed: number): ActionResult;
  perform(action: GameAction, players: RoomPlayer[]): ActionResult;
  getView(playerId: string, players: RoomPlayer[]): GameView;
  getPhase(): RoomPhase;
  getRevision(): number;
  isFinished(): boolean;
}

export class GameRecord {
  public id: string;
  public gameTitle: string;
  public result: string;
  public playerCount: number;
  public finishedAt: string;

  constructor(id: string, gameTitle: string, result: string, playerCount: number, finishedAt: string) {
    this.id = id;
    this.gameTitle = gameTitle;
    this.result = result;
    this.playerCount = playerCount;
    this.finishedAt = finishedAt;
  }
}

export class ContentPackV1 {
  public version: number = 1;
  public id: string = '';
  public title: string = '';
  public gameId: string = '';
  public locale: string = 'zh-CN';
  public entries: string[] = [];
  public enabled: boolean = true;
}
