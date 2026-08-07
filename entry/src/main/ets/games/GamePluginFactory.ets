import { GameId, GamePlugin } from '../core/GameContracts';
import { GameRegistry } from './GameRegistry';

export class GamePluginFactory {
  public static create(id: GameId): GamePlugin {
    return GameRegistry.getInstance().create(id);
  }
}
