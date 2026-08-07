import { GameDefinition, GameId, GamePlugin } from '../core/GameContracts';
import { GameCatalog } from './GameCatalog';
import { UniversalGamePlugin } from './UniversalGamePlugin';

export class GamePluginRegistration {
  public id: GameId;

  constructor(id: GameId) {
    this.id = id;
  }

  public create(): GamePlugin {
    return new UniversalGamePlugin(this.id);
  }
}

export class GameRegistry {
  private static instance: GameRegistry = new GameRegistry();
  private registrations: GamePluginRegistration[] = [];

  private constructor() {
    const definitions: GameDefinition[] = GameCatalog.all();
    for (let index: number = 0; index < definitions.length; index += 1) {
      this.registrations.push(new GamePluginRegistration(definitions[index].id));
    }
  }

  public static getInstance(): GameRegistry {
    return GameRegistry.instance;
  }

  public create(id: GameId): GamePlugin {
    for (let index: number = 0; index < this.registrations.length; index += 1) {
      if (this.registrations[index].id === id) {
        return this.registrations[index].create();
      }
    }
    return new UniversalGamePlugin(GameId.UNDERCOVER);
  }

  public definitions(): GameDefinition[] {
    const result: GameDefinition[] = [];
    for (let index: number = 0; index < this.registrations.length; index += 1) {
      result.push(GameCatalog.find(this.registrations[index].id));
    }
    return result;
  }

  public contains(id: GameId): boolean {
    for (let index: number = 0; index < this.registrations.length; index += 1) {
      if (this.registrations[index].id === id) {
        return true;
      }
    }
    return false;
  }
}
