import { GameDefinition, GameId } from '../core/GameContracts';
import { GameCatalog } from '../games/GameCatalog';

export class RoomInvite {
  public roomCode: string = '';
  public gameId: GameId = GameId.UNDERCOVER;
  public playerCount: number = 2;
  public credential: string = '';
}

export class RoomInviteService {
  public static parse(value: string): RoomInvite | null {
    const prefix: string = 'tabletopparty://room?';
    if (value.length <= prefix.length || value.substring(0, prefix.length).toLowerCase() !== prefix) {
      return null;
    }
    const code: string = RoomInviteService.parameter(value, 'code').toUpperCase();
    const gameText: string = RoomInviteService.parameter(value, 'game');
    const playersText: string = RoomInviteService.parameter(value, 'players');
    const credential: string = RoomInviteService.parameter(value, 'token');
    if (!RoomInviteService.validCode(code) || !RoomInviteService.validGame(gameText) ||
      credential.length < 16 || credential.length > 512) {
      return null;
    }
    const gameId: GameId = GameCatalog.fromString(gameText);
    const definition: GameDefinition = GameCatalog.find(gameId);
    const players: number = Number(playersText);
    if (!Number.isInteger(players) || players < definition.minPlayers || players > definition.maxPlayers) {
      return null;
    }
    const invite: RoomInvite = new RoomInvite();
    invite.roomCode = code;
    invite.gameId = gameId;
    invite.playerCount = players;
    invite.credential = credential;
    return invite;
  }

  public static create(invite: RoomInvite): string {
    return 'tabletopparty://room?code=' + invite.roomCode + '&game=' + invite.gameId +
      '&players=' + invite.playerCount.toString() + '&token=' + encodeURIComponent(invite.credential);
  }

  private static parameter(value: string, name: string): string {
    const queryIndex: number = value.indexOf('?');
    if (queryIndex < 0 || queryIndex + 1 >= value.length) {
      return '';
    }
    const fields: string[] = value.substring(queryIndex + 1).split('&');
    for (let index: number = 0; index < fields.length; index += 1) {
      const separator: number = fields[index].indexOf('=');
      if (separator > 0 && fields[index].substring(0, separator) === name) {
        try {
          return decodeURIComponent(fields[index].substring(separator + 1));
        } catch (error) {
          return '';
        }
      }
    }
    return '';
  }

  private static validCode(value: string): boolean {
    if (value.length !== 6) {
      return false;
    }
    for (let index: number = 0; index < value.length; index += 1) {
      const code: number = value.charCodeAt(index);
      if (!((code >= 48 && code <= 57) || (code >= 65 && code <= 90))) {
        return false;
      }
    }
    return true;
  }

  private static validGame(value: string): boolean {
    const games: GameDefinition[] = GameCatalog.all();
    for (let index: number = 0; index < games.length; index += 1) {
      if (games[index].id === value) {
        return true;
      }
    }
    return false;
  }
}
