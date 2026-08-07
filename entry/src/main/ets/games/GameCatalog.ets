import { GameCategory, GameDefinition, GameId } from '../core/GameContracts';

export class GameCatalog {
  public static all(): GameDefinition[] {
    const games: GameDefinition[] = [];
    games.push(new GameDefinition(GameId.UNDERCOVER, '谁是卧底', GameCategory.DEDUCTION,
      '描述、投票与身份推理', '3–12 人。依次查看词语、描述、投票；卧底坚持到仅剩两人即获胜。',
      3, 12, '#F2E7D5', '卧', true));
    games.push(new GameDefinition(GameId.LANDLORD, '斗地主', GameCategory.CARD,
      '叫分、抢地主与完整出牌回合', '3 人双王扑克牌玩法，包含叫分、地主底牌、常用牌型、炸弹倍率与结算。',
      3, 3, '#F8E1D8', '斗', true));
    games.push(new GameDefinition(GameId.CHINESE_CHESS, '中国象棋', GameCategory.BOARD,
      '完整棋盘与基础电脑对手', '双人对弈，红方先行；支持将军、应将、将帅照面、将死和困毙。',
      2, 2, '#EBD9C4', '象', true));
    games.push(new GameDefinition(GameId.JUNQI, '军棋', GameCategory.BOARD,
      '双人暗棋与秘密布阵', '双人标准暗棋。行营、铁路、工兵、炸弹、地雷和军旗均参与裁决。',
      2, 2, '#DCE8D5', '军', true));
    games.push(new GameDefinition(GameId.WEREWOLF, '狼人杀', GameCategory.DEDUCTION,
      '自动主持昼夜与角色能力', '6–12 人，包含狼人、村民、预言家、女巫、猎人和守卫。',
      6, 12, '#E5E0EB', '狼', true));
    games.push(new GameDefinition(GameId.COLOR_CLASH, '彩牌对决', GameCategory.CARD,
      '原创四色数字与功能牌', '2–10 人。匹配颜色或数字，功能牌改变方向、跳过、加牌或变色。',
      2, 10, '#F7E7A9', '彩', true));
    games.push(new GameDefinition(GameId.GOMOKU, '五子棋', GameCategory.BOARD,
      '15×15 自由规则', '双人落子，横、竖或斜线连续五子及以上获胜，无禁手。',
      2, 2, '#E8D8BB', '五', true));
    games.push(new GameDefinition(GameId.REVERSI, '黑白棋', GameCategory.BOARD,
      '翻转棋子与终局计分', '8×8 棋盘，落子必须夹住对手棋子；无合法落子时自动跳过。',
      2, 2, '#DDE8DF', '黑', true));
    games.push(new GameDefinition(GameId.LUDO, '飞行棋', GameCategory.BOARD,
      '掷骰起飞、撞回与冲线', '2–4 人，每人四枚棋子；掷出六点起飞并获得额外回合。',
      2, 4, '#DEE7F7', '飞', true));
    games.push(new GameDefinition(GameId.SICHUAN_MAHJONG, '四川麻将', GameCategory.CARD,
      '换三张、定缺、血战到底', '4 人 108 张。无吃，有碰杠胡；胡牌后其余玩家继续直到三家胡或牌墙耗尽。',
      4, 4, '#D9EEE4', '麻', true));
    games.push(new GameDefinition(GameId.GUANDAN, '掼蛋', GameCategory.CARD,
      '搭档、级牌与进贡升级', '4 人双副牌搭档玩法，包含顺子、连对、钢板、炸弹、进贡还贡与升级。',
      4, 4, '#F3DED0', '掼', true));
    games.push(new GameDefinition(GameId.DRAW_GUESS, '你画我猜', GameCategory.PARTY,
      '限时画板与实时猜词', '3–12 人轮流作画，其他玩家限时猜词，按速度和成功次数计分。',
      3, 12, '#F2DCE8', '画', true));
    games.push(new GameDefinition(GameId.CHARADES, '你演我猜', GameCategory.PARTY,
      '动作表演与团队计分', '3–12 人。表演者不可说出题面文字，猜中后获得本轮积分。',
      3, 12, '#E9DDF4', '演', true, false));
    games.push(new GameDefinition(GameId.NUMBER_BOMB, '数字炸弹', GameCategory.PARTY,
      '不断收窄范围的快速猜数', '2–12 人轮流猜数，系统持续缩小范围，猜中炸弹者本轮扣分。',
      2, 12, '#F5E4D1', '数', true, false));
    games.push(new GameDefinition(GameId.TRUTH_DARE, '真心话大冒险', GameCategory.PARTY,
      '原创安全题库与轮流挑战', '2–12 人轮流抽取真心话或大冒险，完成挑战即可得分。',
      2, 12, '#F6DDE0', '真', true, false));
    return games;
  }

  public static featured(): GameDefinition[] {
    const result: GameDefinition[] = [];
    const games: GameDefinition[] = GameCatalog.all();
    for (let index: number = 0; index < games.length; index += 1) {
      if (games[index].featured) {
        result.push(games[index]);
      }
    }
    return result;
  }

  public static partyTools(): GameDefinition[] {
    const result: GameDefinition[] = [];
    const games: GameDefinition[] = GameCatalog.all();
    for (let index: number = 0; index < games.length; index += 1) {
      if (!games[index].featured) {
        result.push(games[index]);
      }
    }
    return result;
  }

  public static find(id: GameId): GameDefinition {
    const games: GameDefinition[] = GameCatalog.all();
    for (let index: number = 0; index < games.length; index += 1) {
      if (games[index].id === id) {
        return games[index];
      }
    }
    return games[0];
  }

  public static fromString(id: string): GameId {
    const games: GameDefinition[] = GameCatalog.all();
    for (let index: number = 0; index < games.length; index += 1) {
      if (games[index].id === id) {
        return games[index].id;
      }
    }
    return GameId.UNDERCOVER;
  }
}
