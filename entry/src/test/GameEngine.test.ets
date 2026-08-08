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
import { LandlordPattern, LandlordPatternType, LandlordRules } from '../main/ets/games/LandlordRules';

function twoPlayers(): RoomPlayer[] {
  const players: RoomPlayer[] = [];
  players.push(new RoomPlayer('p0', '甲', 1, true));
  players.push(new RoomPlayer('p1', '乙', 2, false));
  return players;
}

function climbingPower(card: string): number {
  if (card === '大王') {
    return 14;
  }
  if (card === '小王') {
    return 13;
  }
  return ['3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A', '2'].indexOf(card.substring(1));
}

function mahjongPower(tile: string): number {
  const suit: number = ['条', '筒', '万'].indexOf(tile.substring(1));
  return suit * 10 + Number(tile.substring(0, 1));
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

    it('landlordRecognizesAndComparesCompleteCommonPatterns', 0, () => {
      expect(LandlordRules.analyze(['♠3']).type).assertEqual(LandlordPatternType.SINGLE);
      expect(LandlordRules.analyze(['♠4', '♥4']).type).assertEqual(LandlordPatternType.PAIR);
      expect(LandlordRules.analyze(['♠5', '♥5', '♣5', '♦8']).type)
        .assertEqual(LandlordPatternType.TRIPLE_SINGLE);
      expect(LandlordRules.analyze(['♠6', '♥6', '♣6', '♦9', '♠9']).type)
        .assertEqual(LandlordPatternType.TRIPLE_PAIR);
      expect(LandlordRules.analyze(['♠3', '♥4', '♣5', '♦6', '♠7']).type)
        .assertEqual(LandlordPatternType.STRAIGHT);
      expect(LandlordRules.analyze(['♠3', '♥3', '♣4', '♦4', '♠5', '♥5']).type)
        .assertEqual(LandlordPatternType.PAIR_STRAIGHT);
      expect(LandlordRules.analyze(['♠3', '♥3', '♣3', '♠4', '♥4', '♣4']).type)
        .assertEqual(LandlordPatternType.AIRPLANE);
      expect(LandlordRules.analyze(['♠3', '♥3', '♣3', '♠4', '♥4', '♣4', '♦7', '♦8']).type)
        .assertEqual(LandlordPatternType.AIRPLANE_SINGLE);
      expect(LandlordRules.analyze(['♠3', '♥3', '♣3', '♠4', '♥4', '♣4',
        '♦7', '♠7', '♦8', '♠8']).type).assertEqual(LandlordPatternType.AIRPLANE_PAIR);
      expect(LandlordRules.analyze(['♠6', '♥6', '♣6', '♦6', '♠8', '♥9']).type)
        .assertEqual(LandlordPatternType.FOUR_TWO);
      expect(LandlordRules.analyze(['♠6', '♥6', '♣6', '♦6', '♠8', '♥8', '♠9', '♥9']).type)
        .assertEqual(LandlordPatternType.FOUR_TWO_PAIR);
      expect(LandlordRules.analyze(['♠9', '♥9', '♣9', '♦9']).type).assertEqual(LandlordPatternType.BOMB);
      expect(LandlordRules.analyze(['小王', '大王']).type).assertEqual(LandlordPatternType.ROCKET);
      expect(LandlordRules.analyze(['♠10', '♥J', '♣Q', '♦K', '♠A', '♥2']).type)
        .assertEqual(LandlordPatternType.INVALID);

      const lower: LandlordPattern = LandlordRules.analyze(['♠3', '♥4', '♣5', '♦6', '♠7']);
      const higher: LandlordPattern = LandlordRules.analyze(['♠4', '♥5', '♣6', '♦7', '♠8']);
      const wrongLength: LandlordPattern = LandlordRules.analyze(['♠4', '♥5', '♣6', '♦7', '♠8', '♥9']);
      expect(LandlordRules.canBeat(higher, lower)).assertTrue();
      expect(LandlordRules.canBeat(wrongLength, lower)).assertFalse();
      expect(LandlordRules.canBeat(LandlordRules.analyze(['♠9', '♥9', '♣9', '♦9']), higher)).assertTrue();
    });

    it('landlordHintProducesALegalSmallestResponse', 0, () => {
      const hand: string[] = ['大王', '小王', '♠9', '♥9', '♠8', '♥8', '♠4'];
      const previous: string[] = ['♠7', '♥7'];
      const indexes: number[] = LandlordRules.suggest(hand, previous, true);
      const suggestion: LandlordPattern = LandlordRules.analyze(LandlordRules.cardsAt(hand, indexes));
      expect(indexes.length).assertEqual(2);
      expect(suggestion.type).assertEqual(LandlordPatternType.PAIR);
      expect(suggestion.mainRank).assertEqual(LandlordRules.rank('♠8'));
      expect(LandlordRules.canBeat(suggestion, LandlordRules.analyze(previous))).assertTrue();
    });

    it('landlordRedealsWhenNobodyCalls', 0, () => {
      const players: RoomPlayer[] = twoPlayers();
      players.push(new RoomPlayer('p2', '丙', 3, false));
      const plugin: GamePlugin = GameRegistry.getInstance().create(GameId.LANDLORD);
      expect(plugin.start(players, 2026).success).assertTrue();
      expect(plugin.perform(new GameAction('bid', 'p0', '', '', 0), players).success).assertTrue();
      expect(plugin.perform(new GameAction('bid', 'p1', '', '', 0), players).success).assertTrue();
      expect(plugin.perform(new GameAction('bid', 'p2', '', '', 0), players).success).assertTrue();
      const view: GameView = plugin.getView('p0', players);
      expect(view.phase).assertEqual(RoomPhase.REVEAL);
      expect(view.currentPlayerId).assertEqual('p0');
      expect(view.hand.length).assertEqual(17);
      expect(view.status.indexOf('重新发牌') >= 0).assertTrue();
    });

    it('landlordGeneratedActionsCanFinishAFullSeededGame', 0, () => {
      const players: RoomPlayer[] = twoPlayers();
      players.push(new RoomPlayer('p2', '丙', 3, false));
      const plugin: GamePlugin = GameRegistry.getInstance().create(GameId.LANDLORD);
      expect(plugin.start(players, 8080).success).assertTrue();
      expect(plugin.perform(new GameAction('bid', 'p0', '', '', 3), players).success).assertTrue();
      let guard: number = 0;
      while (!plugin.isFinished() && guard < 200) {
        const publicView: GameView = plugin.getView('p0', players);
        const actorId: string = publicView.currentPlayerId;
        const actorView: GameView = plugin.getView(actorId, players);
        const indexes: number[] = LandlordRules.suggest(actorView.hand, actorView.tableCards, true);
        const result = indexes.length > 0 ?
          plugin.perform(new GameAction('play', actorId, indexes.join(',')), players) :
          plugin.perform(new GameAction('pass', actorId), players);
        expect(result.success).assertTrue();
        guard += 1;
      }
      expect(plugin.isFinished()).assertTrue();
      expect(guard < 200).assertTrue();
    });

    it('sortsCardAndMahjongHandsFromHighToLow', 0, () => {
      const landlordPlayers: RoomPlayer[] = twoPlayers();
      landlordPlayers.push(new RoomPlayer('p2', '丙', 3, false));
      const landlord: GamePlugin = GameRegistry.getInstance().create(GameId.LANDLORD);
      expect(landlord.start(landlordPlayers, 20260808).success).assertTrue();
      const landlordHand: string[] = landlord.getView('p0', landlordPlayers).hand;
      for (let index: number = 1; index < landlordHand.length; index += 1) {
        expect(climbingPower(landlordHand[index - 1]) >= climbingPower(landlordHand[index])).assertTrue();
      }

      const mahjongPlayers: RoomPlayer[] = twoPlayers();
      mahjongPlayers.push(new RoomPlayer('p2', '丙', 3, false));
      mahjongPlayers.push(new RoomPlayer('p3', '丁', 4, false));
      const mahjong: GamePlugin = GameRegistry.getInstance().create(GameId.SICHUAN_MAHJONG);
      expect(mahjong.start(mahjongPlayers, 20260808).success).assertTrue();
      const mahjongHand: string[] = mahjong.getView('p0', mahjongPlayers).hand;
      for (let index: number = 1; index < mahjongHand.length; index += 1) {
        expect(mahjongPower(mahjongHand[index - 1]) >= mahjongPower(mahjongHand[index])).assertTrue();
      }
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
