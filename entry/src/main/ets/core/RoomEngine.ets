import {
  ActionResult,
  GameAction,
  GameChoice,
  GameDefinition,
  GameId,
  GamePlugin,
  GameRecord,
  GameView,
  PlayerKind,
  RoomPhase,
  RoomPlayer
} from './GameContracts';
import { GameCatalog } from '../games/GameCatalog';
import { GamePluginFactory } from '../games/GamePluginFactory';
import { LandlordRules } from '../games/LandlordRules';

export class RoomSession {
  public roomCode: string;
  public gameId: GameId;
  public players: RoomPlayer[] = [];
  public hostId: string;
  public targetPlayers: number;
  public revision: number = 0;
  public plugin: GamePlugin;

  constructor(roomCode: string, gameId: GameId, hostId: string, targetPlayers: number, plugin: GamePlugin) {
    this.roomCode = roomCode;
    this.gameId = gameId;
    this.hostId = hostId;
    this.targetPlayers = targetPlayers;
    this.plugin = plugin;
  }
}

export class RoomEngine {
  private session: RoomSession | null = null;
  private records: GameRecord[] = [];
  private recordedRevision: number = -1;

  public createRoom(gameId: GameId, hostNickname: string, targetPlayers: number): RoomSession {
    const definition: GameDefinition = GameCatalog.find(gameId);
    const safeTarget: number = Math.max(definition.minPlayers, Math.min(definition.maxPlayers, targetPlayers));
    const roomCode: string = this.roomCode();
    const hostId: string = 'local-1';
    const plugin: GamePlugin = GamePluginFactory.create(gameId);
    const session: RoomSession = new RoomSession(roomCode, gameId, hostId, safeTarget, plugin);
    session.players.push(new RoomPlayer(hostId, hostNickname.trim().length > 0 ? hostNickname.trim() : '房主',
      1, true));
    this.session = session;
    this.recordedRevision = -1;
    return session;
  }

  public addLocalPlayer(nickname: string = ''): ActionResult {
    if (this.session === null) {
      return new ActionResult(false, '请先创建房间');
    }
    if (this.session.plugin.getPhase() !== RoomPhase.LOBBY) {
      return new ActionResult(false, '游戏开始后不能加入玩家');
    }
    if (this.session.players.length >= this.session.targetPlayers) {
      return new ActionResult(false, '房间人数已满');
    }
    const seat: number = this.session.players.length + 1;
    const name: string = nickname.trim().length > 0 ? nickname.trim() : '玩家' + seat.toString();
    this.session.players.push(new RoomPlayer('local-' + seat.toString(), name, seat, false));
    return new ActionResult(true, name + ' 已加入房间');
  }

  public addRemotePlayer(playerId: string, nickname: string): ActionResult {
    if (this.session === null) {
      return new ActionResult(false, '请先创建房间');
    }
    if (this.session.plugin.getPhase() !== RoomPhase.LOBBY) {
      return new ActionResult(false, '游戏开始后不能加入玩家');
    }
    if (playerId.length < 4 || playerId.length > 80) {
      return new ActionResult(false, '远程玩家标识无效');
    }
    for (let index: number = 0; index < this.session.players.length; index += 1) {
      if (this.session.players[index].id === playerId) {
        return new ActionResult(true, this.session.players[index].nickname + ' 已在房间中');
      }
    }
    if (this.session.players.length >= this.session.targetPlayers) {
      return new ActionResult(false, '房间人数已满');
    }
    const seat: number = this.session.players.length + 1;
    const trimmed: string = nickname.trim();
    const safeNickname: string = trimmed.length > 0 && trimmed.length <= 20 ? trimmed : '附近玩家' + seat.toString();
    this.session.players.push(new RoomPlayer(playerId, safeNickname, seat, false));
    return new ActionResult(true, safeNickname + ' 已加入房间');
  }

  public addAi(kind: PlayerKind): ActionResult {
    if (this.session === null) {
      return new ActionResult(false, '请先创建房间');
    }
    const definition: GameDefinition = GameCatalog.find(this.session.gameId);
    if (!definition.supportsAi) {
      return new ActionResult(false, '当前游戏不支持电脑玩家');
    }
    if (this.session.plugin.getPhase() !== RoomPhase.LOBBY) {
      return new ActionResult(false, '游戏开始后不能加入电脑玩家');
    }
    if (this.session.players.length >= this.session.targetPlayers ||
      this.session.players.length >= definition.maxPlayers) {
      return new ActionResult(false, '房间人数已满');
    }
    const seat: number = this.session.players.length + 1;
    const name: string = kind === PlayerKind.AI_NORMAL ? '棋友 AI' : '入门 AI';
    this.session.players.push(new RoomPlayer('ai-' + seat.toString(), name, seat, false, kind));
    return new ActionResult(true, name + ' 已加入房间');
  }

  public start(): ActionResult {
    if (this.session === null) {
      return new ActionResult(false, '请先创建房间');
    }
    const result: ActionResult = this.session.plugin.start(this.session.players, this.seed(this.session.roomCode));
    if (result.success) {
      this.session.revision = this.session.plugin.getRevision();
    }
    return result;
  }

  public act(action: GameAction): ActionResult {
    if (this.session === null) {
      return new ActionResult(false, '房间不存在');
    }
    const result: ActionResult = this.session.plugin.perform(action, this.session.players);
    if (result.success) {
      this.session.revision = this.session.plugin.getRevision();
      this.captureRecord();
    }
    return result;
  }

  public runAiTurn(): ActionResult {
    if (this.session === null || this.session.plugin.isFinished()) {
      return new ActionResult(false, '当前没有可执行的电脑回合');
    }
    const hostView: GameView = this.session.plugin.getView(this.session.hostId, this.session.players);
    let aiIndex: number = this.findPlayer(hostView.currentPlayerId);
    if (hostView.phase === RoomPhase.VOTING) {
      aiIndex = -1;
      for (let index: number = 0; index < this.session.players.length; index += 1) {
        const candidateView: GameView = this.session.plugin.getView(this.session.players[index].id,
          this.session.players);
        if (this.session.players[index].kind !== PlayerKind.HUMAN && candidateView.canAct) {
          aiIndex = index;
          break;
        }
      }
    }
    if (this.session.gameId === GameId.DRAW_GUESS && aiIndex >= 0 &&
      this.session.players[aiIndex].kind === PlayerKind.HUMAN) {
      aiIndex = -1;
      for (let index: number = 0; index < this.session.players.length; index += 1) {
        if (this.session.players[index].kind !== PlayerKind.HUMAN &&
          this.session.players[index].id !== hostView.currentPlayerId) {
          aiIndex = index;
          break;
        }
      }
    }
    if (aiIndex < 0 || this.session.players[aiIndex].kind === PlayerKind.HUMAN) {
      return new ActionResult(false, '当前不是电脑玩家回合');
    }
    const normal: boolean = this.session.players[aiIndex].kind === PlayerKind.AI_NORMAL;
    const aiView: GameView = this.session.plugin.getView(this.session.players[aiIndex].id, this.session.players);
    if (this.session.gameId === GameId.GOMOKU) {
      const own: string = aiIndex === 0 ? '●' : '○';
      const opponent: string = aiIndex === 0 ? '○' : '●';
      if (normal) {
        for (let index: number = 0; index < hostView.board.length; index += 1) {
          if (hostView.board[index].length === 0 && this.gomokuWouldWin(hostView.board, index, own)) {
            return this.act(new GameAction('place', hostView.currentPlayerId, '', '', index));
          }
        }
        for (let index: number = 0; index < hostView.board.length; index += 1) {
          if (hostView.board[index].length === 0 && this.gomokuWouldWin(hostView.board, index, opponent)) {
            return this.act(new GameAction('place', hostView.currentPlayerId, '', '', index));
          }
        }
      }
      const center: number = 112;
      if (hostView.board[center].length === 0) {
        return this.act(new GameAction('place', hostView.currentPlayerId, '', '', center));
      }
      for (let radius: number = 1; radius < 15; radius += 1) {
        const candidate: number = Math.min(224, center + radius);
        if (hostView.board[candidate].length === 0) {
          return this.act(new GameAction('place', hostView.currentPlayerId, '', '', candidate));
        }
      }
    } else if (this.session.gameId === GameId.REVERSI) {
      const symbol: string = aiIndex === 0 ? '●' : '○';
      let bestIndex: number = -1;
      let bestFlips: number = -1;
      for (let index: number = 0; index < hostView.board.length; index += 1) {
        if (hostView.board[index].length === 0) {
          if (normal) {
            const flips: number = this.reversiFlipCount(hostView.board, index, symbol);
            if (flips > bestFlips) {
              bestFlips = flips;
              bestIndex = index;
            }
            continue;
          }
          const result: ActionResult = this.act(new GameAction('place', hostView.currentPlayerId, '', '', index));
          if (result.success) {
            return result;
          }
        }
      }
      if (normal && bestIndex >= 0 && bestFlips > 0) {
        return this.act(new GameAction('place', hostView.currentPlayerId, '', '', bestIndex));
      }
    } else if (this.session.gameId === GameId.CHINESE_CHESS) {
      const blackPieces: string[] = ['車', '馬', '象', '士', '將', '炮', '卒'];
      const redPieces: string[] = ['俥', '傌', '相', '仕', '帥', '炮', '兵'];
      for (let source: number = 0; source < hostView.board.length; source += 1) {
        if (blackPieces.indexOf(hostView.board[source]) >= 0) {
          const selectResult: ActionResult = this.act(new GameAction('place', hostView.currentPlayerId, '', '', source));
          if (!selectResult.success) {
            continue;
          }
          const orderedTargets: number[] = [];
          if (normal) {
            for (let target: number = 0; target < hostView.board.length; target += 1) {
              if (redPieces.indexOf(hostView.board[target]) >= 0) {
                orderedTargets.push(target);
              }
            }
          }
          for (let target: number = 0; target < hostView.board.length; target += 1) {
            if (blackPieces.indexOf(hostView.board[target]) < 0 && orderedTargets.indexOf(target) < 0) {
              orderedTargets.push(target);
            }
          }
          for (let targetIndex: number = 0; targetIndex < orderedTargets.length; targetIndex += 1) {
            const target: number = orderedTargets[targetIndex];
            const moveResult: ActionResult = this.act(new GameAction('place', hostView.currentPlayerId, '', '', target));
            if (moveResult.success && moveResult.message.indexOf('已改选') !== 0 &&
              moveResult.message.indexOf('已选择') !== 0) {
              return moveResult;
            }
          }
        }
      }
    } else if (this.session.gameId === GameId.JUNQI) {
      const ownSide: string = aiIndex === 0 ? 'R' : 'B';
      for (let source: number = 0; source < aiView.board.length; source += 1) {
        if (source >= aiView.boardOwners.length || aiView.boardOwners[source] !== ownSide) {
          continue;
        }
        const selectResult: ActionResult = this.act(new GameAction('place', aiView.currentPlayerId, '', '', source));
        if (!selectResult.success) {
          continue;
        }
        for (let target: number = 0; target < aiView.board.length; target += 1) {
          if (target < aiView.boardOwners.length && aiView.boardOwners[target] === ownSide) {
            continue;
          }
          const moveResult: ActionResult = this.act(new GameAction('place', aiView.currentPlayerId, '', '', target));
          if (moveResult.success && moveResult.message.indexOf('已选择') !== 0 &&
            moveResult.message.indexOf('已改选') !== 0) {
            return moveResult;
          }
        }
      }
    } else if (this.session.gameId === GameId.LANDLORD && aiView.phase === RoomPhase.REVEAL) {
      return this.act(new GameAction('bid', aiView.currentPlayerId, '', '', normal ? 2 : 1));
    } else if (this.session.gameId === GameId.LANDLORD) {
      const suggested: number[] = LandlordRules.suggest(aiView.hand, aiView.tableCards, normal);
      if (suggested.length > 0) {
        return this.act(new GameAction('play', aiView.currentPlayerId, suggested.join(',')));
      }
      return this.act(new GameAction('pass', aiView.currentPlayerId));
    } else if (this.session.gameId === GameId.GUANDAN) {
      for (let index: number = 0; index < aiView.hand.length; index += 1) {
        const result: ActionResult = this.act(new GameAction('play', aiView.currentPlayerId, index.toString()));
        if (result.success) {
          return result;
        }
      }
      return this.act(new GameAction('pass', aiView.currentPlayerId));
    } else if (this.session.gameId === GameId.SICHUAN_MAHJONG) {
      if (aiView.gameStage === 'exchange') {
        const suits: string[] = ['万', '筒', '条'];
        for (let suitIndex: number = 0; suitIndex < suits.length; suitIndex += 1) {
          const indexes: number[] = [];
          for (let index: number = 0; index < aiView.hand.length; index += 1) {
            if (aiView.hand[index].indexOf(suits[suitIndex]) >= 0 && indexes.length < 3) {
              indexes.push(index);
            }
          }
          if (indexes.length === 3) {
            return this.act(new GameAction('exchange', aiView.currentPlayerId,
              indexes[0].toString() + ',' + indexes[1].toString() + ',' + indexes[2].toString()));
          }
        }
      }
      if (aiView.gameStage === 'missing') {
        let missingSuit: string = '万';
        let missingCount: number = aiView.hand.length + 1;
        const suits: string[] = ['万', '筒', '条'];
        for (let suitIndex: number = 0; suitIndex < suits.length; suitIndex += 1) {
          let suitCount: number = 0;
          for (let index: number = 0; index < aiView.hand.length; index += 1) {
            if (aiView.hand[index].indexOf(suits[suitIndex]) >= 0) {
              suitCount += 1;
            }
          }
          if (suitCount < missingCount) {
            missingCount = suitCount;
            missingSuit = suits[suitIndex];
          }
        }
        return this.act(new GameAction('missing', aiView.currentPlayerId, missingSuit));
      }
      for (let choiceIndex: number = aiView.choices.length - 1; choiceIndex >= 0; choiceIndex -= 1) {
        if (aiView.choices[choiceIndex].actionType === 'win') {
          return this.act(new GameAction('win', aiView.currentPlayerId));
        }
      }
      for (let index: number = 0; index < aiView.hand.length; index += 1) {
        const result: ActionResult = this.act(new GameAction('play', aiView.currentPlayerId, '', '', index));
        if (result.success) {
          return result;
        }
      }
    } else if (this.session.gameId === GameId.NUMBER_BOMB) {
      let low: number = 1;
      let high: number = 100;
      const rangeText: string = aiView.prompt.replace('范围 ', '');
      const rangeParts: string[] = rangeText.split('–');
      if (rangeParts.length === 2) {
        low = Number(rangeParts[0]);
        high = Number(rangeParts[1]);
      }
      return this.act(new GameAction('guess', aiView.currentPlayerId, '', '',
        Math.max(low + 1, Math.min(high - 1, Math.floor((low + high) / 2)))));
    } else if (this.session.gameId === GameId.DRAW_GUESS) {
      if (aiView.currentPlayerId === this.session.players[aiIndex].id) {
        return this.act(new GameAction('aiComplete', aiView.currentPlayerId));
      }
      return this.act(new GameAction('aiGuess', this.session.players[aiIndex].id));
    } else {
      for (let choiceIndex: number = 0; choiceIndex < aiView.choices.length; choiceIndex += 1) {
        const choice: GameChoice = aiView.choices[choiceIndex];
        const result: ActionResult = this.act(new GameAction(choice.actionType, aiView.currentPlayerId,
          choice.first, '', choice.value));
        if (result.success) {
          return result;
        }
      }
    }
    return new ActionResult(false, '电脑玩家暂时没有合法动作');
  }

  private gomokuWouldWin(board: string[], index: number, symbol: string): boolean {
    const directions: number[][] = [[0, 1], [1, 0], [1, 1], [1, -1]];
    const row: number = Math.floor(index / 15);
    const column: number = index % 15;
    for (let directionIndex: number = 0; directionIndex < directions.length; directionIndex += 1) {
      let count: number = 1;
      for (let sign: number = -1; sign <= 1; sign += 2) {
        let nextRow: number = row + directions[directionIndex][0] * sign;
        let nextColumn: number = column + directions[directionIndex][1] * sign;
        while (nextRow >= 0 && nextRow < 15 && nextColumn >= 0 && nextColumn < 15 &&
          board[nextRow * 15 + nextColumn] === symbol) {
          count += 1;
          nextRow += directions[directionIndex][0] * sign;
          nextColumn += directions[directionIndex][1] * sign;
        }
      }
      if (count >= 5) {
        return true;
      }
    }
    return false;
  }

  private reversiFlipCount(board: string[], target: number, symbol: string): number {
    if (target < 0 || target >= 64 || board[target].length > 0) {
      return 0;
    }
    const opponent: string = symbol === '●' ? '○' : '●';
    const directions: number[][] = [[-1, -1], [-1, 0], [-1, 1], [0, -1], [0, 1], [1, -1], [1, 0], [1, 1]];
    const row: number = Math.floor(target / 8);
    const column: number = target % 8;
    let count: number = 0;
    for (let directionIndex: number = 0; directionIndex < directions.length; directionIndex += 1) {
      let nextRow: number = row + directions[directionIndex][0];
      let nextColumn: number = column + directions[directionIndex][1];
      let line: number = 0;
      while (nextRow >= 0 && nextRow < 8 && nextColumn >= 0 && nextColumn < 8 &&
        board[nextRow * 8 + nextColumn] === opponent) {
        line += 1;
        nextRow += directions[directionIndex][0];
        nextColumn += directions[directionIndex][1];
      }
      if (line > 0 && nextRow >= 0 && nextRow < 8 && nextColumn >= 0 && nextColumn < 8 &&
        board[nextRow * 8 + nextColumn] === symbol) {
        count += line;
      }
    }
    return count;
  }

  public view(playerId: string): GameView {
    if (this.session === null) {
      return new GameView();
    }
    return this.session.plugin.getView(playerId, this.session.players);
  }

  public getSession(): RoomSession | null {
    return this.session;
  }

  public getRecords(): GameRecord[] {
    return this.records.slice();
  }

  public setRecords(records: GameRecord[]): void {
    this.records = records.slice(0, 50);
  }

  public endRoom(): void {
    this.captureRecord();
    this.session = null;
  }

  private captureRecord(): void {
    if (this.session === null || !this.session.plugin.isFinished() ||
      this.recordedRevision === this.session.plugin.getRevision()) {
      return;
    }
    const definition: GameDefinition = GameCatalog.find(this.session.gameId);
    const view: GameView = this.session.plugin.getView(this.session.hostId, this.session.players);
    const record: GameRecord = new GameRecord(
      this.session.roomCode + '-' + this.session.plugin.getRevision().toString(), definition.title,
      view.winner, this.session.players.length, new Date().toLocaleString());
    this.records.unshift(record);
    this.recordedRevision = this.session.plugin.getRevision();
  }

  private roomCode(): string {
    const value: string = Date.now().toString(36).toUpperCase();
    const padded: string = '000000' + value;
    return padded.substring(padded.length - 6);
  }

  private findPlayer(id: string): number {
    if (this.session === null) {
      return -1;
    }
    for (let index: number = 0; index < this.session.players.length; index += 1) {
      if (this.session.players[index].id === id) {
        return index;
      }
    }
    return -1;
  }

  private seed(value: string): number {
    let result: number = 7;
    for (let index: number = 0; index < value.length; index += 1) {
      result = (result * 31 + value.charCodeAt(index)) & 0x7FFFFFFF;
    }
    return result;
  }
}
