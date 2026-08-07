import { ContentPackV1, GameId } from '../core/GameContracts';
import { BuiltInContent } from './BuiltInContent';
import { GameCatalog } from '../games/GameCatalog';

export class ContentSummary {
  public gameId: GameId;
  public title: string;
  public builtInCount: number;
  public customCount: number;

  constructor(gameId: GameId, title: string, builtInCount: number, customCount: number = 0) {
    this.gameId = gameId;
    this.title = title;
    this.builtInCount = builtInCount;
    this.customCount = customCount;
  }
}

export class ContentPackSummary {
  public id: string;
  public title: string;
  public gameTitle: string;
  public entryCount: number;
  public enabled: boolean;

  constructor(id: string, title: string, gameTitle: string, entryCount: number, enabled: boolean) {
    this.id = id;
    this.title = title;
    this.gameTitle = gameTitle;
    this.entryCount = entryCount;
    this.enabled = enabled;
  }
}

export class ContentLibrary {
  private customPacks: ContentPackV1[] = [];

  public summaries(): ContentSummary[] {
    const values: ContentSummary[] = [];
    values.push(new ContentSummary(GameId.UNDERCOVER, '卧底词组', BuiltInContent.undercoverPairs().length,
      this.customEntryCount(GameId.UNDERCOVER)));
    values.push(new ContentSummary(GameId.DRAW_GUESS, '画猜题库', BuiltInContent.drawWords().length,
      this.customEntryCount(GameId.DRAW_GUESS)));
    values.push(new ContentSummary(GameId.CHARADES, '演猜题库', BuiltInContent.charadesWords().length,
      this.customEntryCount(GameId.CHARADES)));
    values.push(new ContentSummary(GameId.TRUTH_DARE, '真心话', BuiltInContent.truthQuestions().length,
      this.customEntryCount(GameId.TRUTH_DARE)));
    values.push(new ContentSummary(GameId.TRUTH_DARE, '大冒险', BuiltInContent.dareChallenges().length,
      this.customEntryCount(GameId.TRUTH_DARE)));
    values.push(new ContentSummary(GameId.WEREWOLF, '狼人杀配置', BuiltInContent.werewolfSetups().length,
      this.customEntryCount(GameId.WEREWOLF)));
    return values;
  }

  public importPack(pack: ContentPackV1): string {
    if (pack.version !== 1) {
      return '只支持 ContentPackV1';
    }
    if (pack.id.trim().length === 0 || pack.title.trim().length === 0) {
      return '内容包缺少 id 或标题';
    }
    let supportedGame: boolean = false;
    for (let gameIndex: number = 0; gameIndex < GameCatalog.all().length; gameIndex += 1) {
      if (GameCatalog.all()[gameIndex].id === pack.gameId) {
        supportedGame = true;
      }
    }
    if (!supportedGame) {
      return '内容包游戏类型不受支持';
    }
    if (pack.entries.length === 0 || pack.entries.length > 1000) {
      return '内容条目需为 1–1000 条';
    }
    for (let packIndex: number = 0; packIndex < this.customPacks.length; packIndex += 1) {
      if (this.customPacks[packIndex].id === pack.id) {
        return '已存在相同 id 的内容包';
      }
    }
    const cleanEntries: string[] = [];
    for (let index: number = 0; index < pack.entries.length; index += 1) {
      const value: string = pack.entries[index].trim();
      const safe: boolean = value.indexOf('<script') < 0 && value.indexOf('function') < 0 &&
        value.indexOf('=>') < 0 && value.indexOf('import ') < 0;
      if (safe && value.length > 0 && value.length <= 80 && cleanEntries.indexOf(value) < 0) {
        cleanEntries.push(value);
      }
    }
    if (cleanEntries.length === 0) {
      return '没有可导入的有效条目';
    }
    pack.entries = cleanEntries;
    this.customPacks.push(pack);
    return '已导入 ' + cleanEntries.length.toString() + ' 条内容';
  }

  public importJson(jsonText: string): string {
    if (jsonText.length === 0 || jsonText.length > 200000) {
      return 'JSON 内容需为 1–200000 字符';
    }
    try {
      const pack: ContentPackV1 = JSON.parse(jsonText);
      return this.importPack(pack);
    } catch (error) {
      return 'JSON 格式错误，无法读取 ContentPackV1';
    }
  }

  public packCount(): number {
    return this.customPacks.length;
  }

  public packSummaries(): ContentPackSummary[] {
    const result: ContentPackSummary[] = [];
    for (let index: number = 0; index < this.customPacks.length; index += 1) {
      const pack: ContentPackV1 = this.customPacks[index];
      const gameId: GameId = GameCatalog.fromString(pack.gameId);
      result.push(new ContentPackSummary(pack.id, pack.title, GameCatalog.find(gameId).title,
        pack.entries.length, pack.enabled));
    }
    return result;
  }

  public togglePack(id: string): string {
    for (let index: number = 0; index < this.customPacks.length; index += 1) {
      if (this.customPacks[index].id === id) {
        this.customPacks[index].enabled = !this.customPacks[index].enabled;
        return this.customPacks[index].enabled ? '内容包已启用' : '内容包已停用';
      }
    }
    return '未找到内容包';
  }

  public exportCustomData(): string {
    const lines: string[] = [];
    for (let index: number = 0; index < this.customPacks.length; index += 1) {
      const entries: string[] = [];
      for (let entryIndex: number = 0; entryIndex < this.customPacks[index].entries.length; entryIndex += 1) {
        entries.push(encodeURIComponent(this.customPacks[index].entries[entryIndex]));
      }
      lines.push(encodeURIComponent(this.customPacks[index].id) + '^' +
        encodeURIComponent(this.customPacks[index].title) + '^' + this.customPacks[index].gameId + '^' +
        encodeURIComponent(this.customPacks[index].locale) + '^' + entries.join(',') + '^' +
        (this.customPacks[index].enabled ? '1' : '0'));
    }
    return lines.join('~');
  }

  public restoreCustomData(value: string): void {
    this.customPacks = [];
    if (value.length === 0) {
      return;
    }
    const lines: string[] = value.split('~');
    for (let index: number = 0; index < lines.length; index += 1) {
      const fields: string[] = lines[index].split('^');
      if (fields.length !== 5 && fields.length !== 6) {
        continue;
      }
      const pack: ContentPackV1 = new ContentPackV1();
      pack.id = decodeURIComponent(fields[0]);
      pack.title = decodeURIComponent(fields[1]);
      pack.gameId = fields[2];
      pack.locale = decodeURIComponent(fields[3]);
      const encodedEntries: string[] = fields[4].split(',');
      for (let entryIndex: number = 0; entryIndex < encodedEntries.length; entryIndex += 1) {
        pack.entries.push(decodeURIComponent(encodedEntries[entryIndex]));
      }
      pack.enabled = fields.length === 5 || fields[5] !== '0';
      const enabled: boolean = pack.enabled;
      this.importPack(pack);
      pack.enabled = enabled;
    }
  }

  private customEntryCount(gameId: GameId): number {
    let count: number = 0;
    for (let index: number = 0; index < this.customPacks.length; index += 1) {
      if (this.customPacks[index].gameId === gameId && this.customPacks[index].enabled) {
        count += this.customPacks[index].entries.length;
      }
    }
    return count;
  }
}
