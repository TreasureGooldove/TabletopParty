import {
  ActionResult,
  GameAction,
  GameDefinition,
  GameId,
  GameRecord,
  GameView,
  PlayerKind,
  RoomPlayer
} from '../core/GameContracts';
import { RoomEngine, RoomSession } from '../core/RoomEngine';
import { GameCatalog } from '../games/GameCatalog';
import { ContentLibrary } from '../services/ContentLibrary';
import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { LocalPreferences, SavedPreferences } from '../services/LocalPreferences';
import { RoomInvite, RoomInviteService } from '../services/RoomInviteService';

export class AppSettings {
  public reduceMotion: boolean = false;
  public vibration: boolean = true;
  public largeText: boolean = false;
  public privateReveal: boolean = true;
}

export class PartyAppStore {
  private static instance: PartyAppStore = new PartyAppStore();
  private roomEngine: RoomEngine = new RoomEngine();
  private selectedGameId: GameId = GameId.UNDERCOVER;
  private currentSeatIndex: number = 0;
  private contentLibrary: ContentLibrary = new ContentLibrary();
  private localPreferences: LocalPreferences = new LocalPreferences();
  private pendingRoomInvite: RoomInvite | null = null;
  private abilityContext: common.UIAbilityContext | null = null;
  public nickname: string = '玩家';
  public targetPlayers: number = 4;
  public message: string = '选择一款游戏，和身边的人立即开局';
  public settings: AppSettings = new AppSettings();

  public static getInstance(): PartyAppStore {
    return PartyAppStore.instance;
  }

  public async initialize(context: common.UIAbilityContext): Promise<void> {
    this.abilityContext = context;
    const saved: SavedPreferences = await this.localPreferences.initialize(context);
    this.nickname = saved.nickname;
    this.settings.reduceMotion = saved.reduceMotion;
    this.settings.vibration = saved.vibration;
    this.settings.largeText = saved.largeText;
    this.settings.privateReveal = saved.privateReveal;
    this.roomEngine.setRecords(saved.records);
    this.contentLibrary.restoreCustomData(saved.customContent);
  }

  public async setGameLandscape(enabled: boolean): Promise<ActionResult> {
    if (this.abilityContext === null) {
      return new ActionResult(false, '窗口尚未准备完成');
    }
    try {
      const mainWindow: window.Window = await window.getLastWindow(this.abilityContext);
      await mainWindow.setPreferredOrientation(enabled ? window.Orientation.AUTO_ROTATION_LANDSCAPE :
        window.Orientation.AUTO_ROTATION_PORTRAIT);
      return new ActionResult(true, enabled ? '已切换为横屏对局' : '已恢复竖屏界面');
    } catch (error) {
      return new ActionResult(false, '当前窗口暂不支持切换方向');
    }
  }

  public async setGameFullscreen(enabled: boolean): Promise<ActionResult> {
    if (this.abilityContext === null) {
      return new ActionResult(false, '窗口尚未准备完成');
    }
    try {
      const mainWindow: window.Window = await window.getLastWindow(this.abilityContext);
      await mainWindow.setWindowLayoutFullScreen(enabled);
      await mainWindow.setWindowSystemBarEnable(enabled ? [] : ['status', 'navigation']);
      return new ActionResult(true, enabled ? '已进入全屏对局' : '已退出全屏对局');
    } catch (error) {
      return new ActionResult(false, '当前窗口暂不支持全屏切换');
    }
  }

  public selectGame(id: GameId): void {
    this.selectedGameId = id;
    const definition: GameDefinition = GameCatalog.find(id);
    this.targetPlayers = definition.minPlayers;
    if (id === GameId.UNDERCOVER || id === GameId.DRAW_GUESS) {
      this.targetPlayers = 4;
    } else if (id === GameId.WEREWOLF) {
      this.targetPlayers = 6;
    }
    this.message = '已选择 ' + definition.title;
  }

  public selectedDefinition(): GameDefinition {
    return GameCatalog.find(this.selectedGameId);
  }

  public selectedId(): GameId {
    return this.selectedGameId;
  }

  public receiveInvite(value: string): ActionResult {
    const invite: RoomInvite | null = RoomInviteService.parse(value);
    if (invite === null) {
      return new ActionResult(false, '邀请链接无效或已损坏');
    }
    this.pendingRoomInvite = invite;
    this.selectedGameId = invite.gameId;
    this.targetPlayers = invite.playerCount;
    const definition: GameDefinition = GameCatalog.find(invite.gameId);
    this.message = '收到 ' + definition.title + ' 房间邀请：' + invite.roomCode;
    return new ActionResult(true, this.message);
  }

  public pendingInvite(): RoomInvite | null {
    return this.pendingRoomInvite;
  }

  public clearPendingInvite(): void {
    this.pendingRoomInvite = null;
  }

  public createRoom(): RoomSession {
    const session: RoomSession = this.roomEngine.createRoom(this.selectedGameId, this.nickname, this.targetPlayers);
    this.currentSeatIndex = 0;
    this.message = '房间 ' + session.roomCode + ' 已创建';
    this.savePreferences();
    return session;
  }

  public addLocalPlayer(): ActionResult {
    const result: ActionResult = this.roomEngine.addLocalPlayer();
    this.message = result.message;
    return result;
  }

  public addRemotePlayer(playerId: string, nickname: string): ActionResult {
    const result: ActionResult = this.roomEngine.addRemotePlayer(playerId, nickname);
    this.message = result.message;
    return result;
  }

  public addAi(normal: boolean): ActionResult {
    const result: ActionResult = this.roomEngine.addAi(normal ? PlayerKind.AI_NORMAL : PlayerKind.AI_EASY);
    this.message = result.message;
    return result;
  }

  public fillAiPlayers(normal: boolean): void {
    const session: RoomSession | null = this.roomEngine.getSession();
    if (session === null) {
      return;
    }
    while (session.players.length < session.targetPlayers) {
      const result: ActionResult = this.roomEngine.addAi(normal ? PlayerKind.AI_NORMAL : PlayerKind.AI_EASY);
      if (!result.success) {
        this.message = result.message;
        return;
      }
    }
    this.message = '已用' + (normal ? '普通' : '简单') + ' AI 补齐全部席位';
  }

  public fillLocalPlayers(): void {
    const session: RoomSession | null = this.roomEngine.getSession();
    if (session === null) {
      return;
    }
    while (session.players.length < session.targetPlayers) {
      this.roomEngine.addLocalPlayer();
    }
    this.message = '已补齐 ' + session.players.length.toString() + ' 个本机席位';
  }

  public startGame(): ActionResult {
    const result: ActionResult = this.roomEngine.start();
    this.message = result.message;
    return result;
  }

  public act(type: string, value: number = -1, first: string = '', second: string = ''): ActionResult {
    const player: RoomPlayer | null = this.currentPlayer();
    if (player === null) {
      return new ActionResult(false, '当前席位不存在');
    }
    const action: GameAction = new GameAction(type, player.id, first, second, value);
    const result: ActionResult = this.roomEngine.act(action);
    this.message = result.message;
    return result;
  }

  public runAiTurn(): ActionResult {
    const result: ActionResult = this.roomEngine.runAiTurn();
    if (result.success) {
      this.message = result.message;
    }
    return result;
  }

  public session(): RoomSession | null {
    return this.roomEngine.getSession();
  }

  public currentView(): GameView {
    const player: RoomPlayer | null = this.currentPlayer();
    return this.roomEngine.view(player === null ? '' : player.id);
  }

  public currentPlayer(): RoomPlayer | null {
    const session: RoomSession | null = this.roomEngine.getSession();
    if (session === null || session.players.length === 0) {
      return null;
    }
    this.currentSeatIndex = Math.max(0, Math.min(this.currentSeatIndex, session.players.length - 1));
    return session.players[this.currentSeatIndex];
  }

  public selectSeat(index: number): void {
    const session: RoomSession | null = this.roomEngine.getSession();
    if (session !== null && index >= 0 && index < session.players.length) {
      this.currentSeatIndex = index;
      this.message = '已切换到 ' + session.players[index].nickname + ' 的私密视图';
    }
  }

  public currentSeat(): number {
    return this.currentSeatIndex;
  }

  public records(): GameRecord[] {
    return this.roomEngine.getRecords();
  }

  public content(): ContentLibrary {
    return this.contentLibrary;
  }

  public endRoom(): void {
    this.roomEngine.endRoom();
    this.currentSeatIndex = 0;
    this.message = '房间已结束，私密状态已清除';
    this.savePreferences();
  }

  public savePreferences(): void {
    const saved: SavedPreferences = new SavedPreferences();
    saved.nickname = this.nickname;
    saved.reduceMotion = this.settings.reduceMotion;
    saved.vibration = this.settings.vibration;
    saved.largeText = this.settings.largeText;
    saved.privateReveal = this.settings.privateReveal;
    saved.records = this.roomEngine.getRecords();
    saved.customContent = this.contentLibrary.exportCustomData();
    this.localPreferences.saveProfile(saved).catch(() => {
      return;
    });
  }
}
