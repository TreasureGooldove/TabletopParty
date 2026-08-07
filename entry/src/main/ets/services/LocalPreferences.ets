import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { GameRecord } from '../core/GameContracts';

export class SavedPreferences {
  public nickname: string = '玩家';
  public reduceMotion: boolean = false;
  public vibration: boolean = true;
  public largeText: boolean = false;
  public privateReveal: boolean = true;
  public records: GameRecord[] = [];
  public customContent: string = '';
}

export class LocalPreferences {
  private store: preferences.Preferences | null = null;

  public async initialize(context: common.UIAbilityContext): Promise<SavedPreferences> {
    const saved: SavedPreferences = new SavedPreferences();
    try {
      this.store = await preferences.getPreferences(context, { name: 'tabletop_party_local_v1' });
      if (this.store !== null) {
        saved.nickname = (await this.store.get('nickname', '玩家')).toString();
        saved.reduceMotion = await this.store.get('reduceMotion', false) === true;
        saved.vibration = await this.store.get('vibration', true) === true;
        saved.largeText = await this.store.get('largeText', false) === true;
        saved.privateReveal = await this.store.get('privateReveal', true) === true;
        saved.records = this.decodeRecords((await this.store.get('records', '')).toString());
        saved.customContent = (await this.store.get('customContent', '')).toString();
      }
    } catch (error) {
      this.store = null;
    }
    return saved;
  }

  public async saveProfile(saved: SavedPreferences): Promise<void> {
    if (this.store === null) {
      return;
    }
    try {
      await this.store.put('nickname', saved.nickname);
      await this.store.put('reduceMotion', saved.reduceMotion);
      await this.store.put('vibration', saved.vibration);
      await this.store.put('largeText', saved.largeText);
      await this.store.put('privateReveal', saved.privateReveal);
      await this.store.put('records', this.encodeRecords(saved.records));
      await this.store.put('customContent', saved.customContent);
      await this.store.flush();
    } catch (error) {
      return;
    }
  }

  private encodeRecords(records: GameRecord[]): string {
    const lines: string[] = [];
    const count: number = Math.min(50, records.length);
    for (let index: number = 0; index < count; index += 1) {
      lines.push(encodeURIComponent(records[index].id) + '^' + encodeURIComponent(records[index].gameTitle) + '^' +
        encodeURIComponent(records[index].result) + '^' + records[index].playerCount.toString() + '^' +
        encodeURIComponent(records[index].finishedAt));
    }
    return lines.join('~');
  }

  private decodeRecords(value: string): GameRecord[] {
    const records: GameRecord[] = [];
    if (value.length === 0) {
      return records;
    }
    const lines: string[] = value.split('~');
    for (let index: number = 0; index < lines.length; index += 1) {
      const fields: string[] = lines[index].split('^');
      if (fields.length === 5) {
        records.push(new GameRecord(decodeURIComponent(fields[0]), decodeURIComponent(fields[1]),
          decodeURIComponent(fields[2]), Number(fields[3]), decodeURIComponent(fields[4])));
      }
    }
    return records;
  }
}
