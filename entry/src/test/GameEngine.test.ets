import { describe, expect, it } from '@ohos/hypium';
import {
  GameAction,
  GameDefinition,
  GameId,
  GamePlugin,
  GameView,
  PlayerKind,
  RoomPhase,
  RoomPlayer
} from '../main/ets/core/GameContracts';
import { RoomEngine } from '../main/ets/core/RoomEngine';
import { GameCatalog } from '../main/ets/games/GameCatalog';
import { GameRegistry } from '../main/ets/games/GameRegistry';

function twoPlayers(): RoomPlayer[] {
  const players: RoomPlayer[] = [];
  players.push(new RoomPlayer('p0', '甲', 1, true));
  players.push(new RoomPlayer('p1', '乙', 2, false));
  return players;
}

export default function gameEngineTest(): void {
  describe('GameEngineTest', () => {
    it('registersAllFifteenPlayablePlugins', 0, () => {
      const registry: GameRegistry = GameRegistry.getInstance();
      expect(registry.definitions().length).assertEqual(15);
      expect(registry.contains(GameId.GUANDAN)).assertTrue();
      expect(registry.contains(GameId.TRUTH_DARE)).assertTrue();
      const games: GameDefinition[] = GameCatalog.all();
      for (let index: number = 0; index < games.length; index += 1) {
        expect(games[index].supportsAi).assertTrue();
      }
    });

    it('allowsAiSeatsInEveryGame', 0, () => {
      const games: GameDefinition[] = GameCatalog.all();
      for (let gameIndex: number = 0; gameIndex < games.length; gameIndex += 1) {
        const engine: RoomEngine = new RoomEngine();
        const session = engine.createRoom(games[gameIndex].id, '玩家', games[gameIndex].minPlayers);
        while (session.players.length < games[gameIndex].minPlayers) {
          expect(engine.addAi(PlayerKind.AI_NORMAL).success).assertTrue();
        }
        expect(engine.start().success).assertTrue();
      }
    });

    it('runsRuleValidatedAiForLandlordAndUndercover', 0, () => {
      const landlord: RoomEngine = new RoomEngine();
      const landlordRoom = landlord.createRoom(GameId.LANDLORD, '地主玩家', 3);
      expect(landlord.addAi(PlayerKind.AI_EASY).success).assertTrue();
      expect(landlord.addAi(PlayerKind.AI_NORMAL).success).assertTrue();
      expect(landlord.start().success).assertTrue();
      expect(landlord.act(new GameAction('bid', landlordRoom.hostId, '', '', 0)).success).assertTrue();
      expect(landlord.runAiTurn().success).assertTrue();

      const undercover: RoomEngine = new RoomEngine();
      const undercoverRoom = undercover.createRoom(GameId.UNDERCOVER, '平民玩家', 3);
      expect(undercover.addAi(PlayerKind.AI_EASY).success).assertTrue();
      expect(undercover.addAi(PlayerKind.AI_NORMAL).success).assertTrue();
      expect(undercover.start().success).assertTrue();
      expect(undercover.act(new GameAction('next', undercoverRoom.hostId)).success).assertTrue();
      expect(undercover.runAiTurn().success).assertTrue();
    });

    it('startsEveryFeaturedGameAndHidesSpectatorSecrets', 0, () => {
      const games: GameDefinition[] = GameCatalog.featured();
      for (let gameIndex: number = 0; gameIndex < games.length; gameIndex += 1) {
        const players: RoomPlayer[] = [];
        for (let playerIndex: number = 0; playerIndex < games[gameIndex].minPlayers; playerIndex += 1) {
          players.push(new RoomPlayer('p' + playerIndex.toString(), '玩家' + (playerIndex + 1).toString(),
            playerIndex + 1, playerIndex === 0));
        }
        const plugin: GamePlugin = GameRegistry.getInstance().create(games[gameIndex].id);
        expect(plugin.start(players, 100 + gameIndex).success).assertTrue();
        expect(plugin.getPhase() !== RoomPhase.LOBBY).assertTrue();
        const spectator: GameView = plugin.getView('not-a-seat', players);
        expect(spectator.privateText).assertEqual('');
        expect(spectator.hand.length).assertEqual(0);
      }
    });

    it('acceptsOneIdempotentRemoteSeatBeforeStart', 0, () => {
      const engine: RoomEngine = new RoomEngine();
      const session = engine.createRoom(GameId.GOMOKU, '房主', 2);
      expect(engine.addRemotePlayer('guest-device-1', '小桌友').success).assertTrue();
      expect(engine.addRemotePlayer('guest-device-1', '重复昵称').success).assertTrue();
      expect(session.players.length).assertEqual(2);
      expect(engine.start().success).assertTrue();
      expect(engine.addRemotePlayer('guest-device-2', '迟到玩家').success).assertFalse();
    });

    it('gomokuDetectsFiveInRow', 0, () => {
      const players: RoomPlayer[] = twoPlayers();
      const plugin: GamePlugin = GameRegistry.getInstance().create(GameId.GOMOKU);
      expect(plugin.start(players, 7).success).assertTrue();
      const moves: number[] = [0, 15, 1, 16, 2, 17, 3, 18, 4];
      for (let index: number = 0; index < moves.length; index += 1) {
        const actor: string = index % 2 === 0 ? 'p0' : 'p1';
        expect(plugin.perform(new GameAction('place', actor, '', '', moves[index]), players).success).assertTrue();
      }
      expect(plugin.getPhase()).assertEqual(RoomPhase.FINISHED);
      expect(plugin.getView('p0', players).winner.indexOf('甲')).assertLarger(-1);
    });

    it('reversiFlipsCapturedPieceAndRejectsOccupiedCell', 0, () => {
      const players: RoomPlayer[] = twoPlayers();
      const plugin: GamePlugin = GameRegistry.getInstance().create(GameId.REVERSI);
      plugin.start(players, 8);
      expect(plugin.perform(new GameAction('place', 'p0', '', '', 19), players).success).assertTrue();
      expect(plugin.getView('p0', players).board[27]).assertEqual('●');
      expect(plugin.perform(new GameAction('place', 'p1', '', '', 19), players).success).assertFalse();
    });

    it('undercoverProjectsOnlyCurrentPlayersSecret', 0, () => {
      const players: RoomPlayer[] = twoPlayers();
      players.push(new RoomPlayer('p2', '丙', 3, false));
      players.push(new RoomPlayer('p3', '丁', 4, false));
      const plugin: GamePlugin = GameRegistry.getInstance().create(GameId.UNDERCOVER);
      plugin.start(players, 9);
      expect(plugin.getView('p0', players).privateText.indexOf('你的词语：')).assertEqual(0);
      expect(plugin.getView('nobody', players).privateText).assertEqual('');
      expect(plugin.getView('p0', players).hand.length).assertEqual(0);
    });

    it('chineseChessRejectsWrongSideAndIllegalMove', 0, () => {
      const players: RoomPlayer[] = twoPlayers();
      const plugin: GamePlugin = GameRegistry.getInstance().create(GameId.CHINESE_CHESS);
      plugin.start(players, 10);
      expect(plugin.perform(new GameAction('place', 'p1', '', '', 0), players).success).assertFalse();
      expect(plugin.perform(new GameAction('place', 'p0', '', '', 81), players).success).assertTrue();
      expect(plugin.perform(new GameAction('place', 'p0', '', '', 71), players).success).assertFalse();
    });

    it('junqiCreatesLegalRandomFormationAndKeepsEnemyRanksSecret', 0, () => {
      const players: RoomPlayer[] = twoPlayers();
      const plugin: GamePlugin = GameRegistry.getInstance().create(GameId.JUNQI);
      expect(plugin.start(players, 20260807).success).assertTrue();
      const redView: GameView = plugin.getView('p0', players);
      const blueView: GameView = plugin.getView('p1', players);
      let redCount: number = 0;
      let blueCount: number = 0;
      let redFlagCount: number = 0;
      let blueFlagCount: number = 0;
      let maskedBlueCount: number = 0;
      for (let index: number = 0; index < redView.boardOwners.length; index += 1) {
        if (redView.boardOwners[index] === 'R') {
          redCount += 1;
        } else if (redView.boardOwners[index] === 'B') {
          blueCount += 1;
        }
        if (redView.board[index] === '旗') {
          redFlagCount += 1;
          expect(index === 56 || index === 58).assertTrue();
        }
        if (blueView.board[index] === '旗') {
          blueFlagCount += 1;
          expect(index === 1 || index === 3).assertTrue();
        }
        if (redView.boardOwners[index] === 'B' && redView.board[index] === '◆') {
          maskedBlueCount += 1;
        }
        if (redView.board[index] === '雷') {
          expect(Math.floor(index / 5) >= 10).assertTrue();
        }
        if (blueView.board[index] === '雷') {
          expect(Math.floor(index / 5) <= 1).assertTrue();
        }
        if (redView.board[index] === '炸') {
          expect(Math.floor(index / 5) !== 6).assertTrue();
        }
        if (blueView.board[index] === '炸') {
          expect(Math.floor(index / 5) !== 5).assertTrue();
        }
      }
      expect(redCount).assertEqual(25);
      expect(blueCount).assertEqual(25);
      expect(redFlagCount).assertEqual(1);
      expect(blueFlagCount).assertEqual(1);
      expect(maskedBlueCount).assertEqual(25);
    });

    it('landlordBidsPlaysAndResetsAfterTwoPasses', 0, () => {
      const players: RoomPlayer[] = twoPlayers();
      players.push(new RoomPlayer('p2', '丙', 3, false));
      const plugin: GamePlugin = GameRegistry.getInstance().create(GameId.LANDLORD);
      plugin.start(players, 11);
      expect(plugin.getPhase()).assertEqual(RoomPhase.REVEAL);
      expect(plugin.perform(new GameAction('bid', 'p0', '', '', 3), players).success).assertTrue();
      expect(plugin.getPhase()).assertEqual(RoomPhase.PLAYING);
      expect(plugin.perform(new GameAction('play', 'p0', '0', '', -1), players).success).assertTrue();
      expect(plugin.perform(new GameAction('pass', 'p1'), players).success).assertTrue();
      expect(plugin.perform(new GameAction('pass', 'p2'), players).success).assertTrue();
      expect(plugin.getView('p0', players).currentPlayerId).assertEqual('p0');
    });

    it('normalBoardAiReturnsLegalMoveWithinOneSecond', 0, () => {
      const engine: RoomEngine = new RoomEngine();
      engine.createRoom(GameId.GOMOKU, '甲', 2);
      expect(engine.addAi(PlayerKind.AI_NORMAL).success).assertTrue();
      expect(engine.start().success).assertTrue();
      expect(engine.act(new GameAction('place', 'local-1', '', '', 112)).success).assertTrue();
      const started: number = Date.now();
      expect(engine.runAiTurn().success).assertTrue();
      expect(Date.now() - started < 1000).assertTrue();
    });
  });
}
