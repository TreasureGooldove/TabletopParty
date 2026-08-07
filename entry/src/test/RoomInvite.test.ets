import { describe, expect, it } from '@ohos/hypium';
import { GameId } from '../main/ets/core/GameContracts';
import { RoomInvite, RoomInviteService } from '../main/ets/services/RoomInviteService';

export default function roomInviteTest(): void {
  describe('RoomInviteTest', () => {
    it('roundTripsValidatedInvite', 0, () => {
      const invite: RoomInvite = new RoomInvite();
      invite.roomCode = 'AB12CD';
      invite.gameId = GameId.GOMOKU;
      invite.playerCount = 2;
      invite.credential = 'temporary-credential-1234567890';
      const parsed: RoomInvite | null = RoomInviteService.parse(RoomInviteService.create(invite));
      expect(parsed !== null).assertTrue();
      if (parsed !== null) {
        expect(parsed.roomCode).assertEqual('AB12CD');
        expect(parsed.gameId).assertEqual(GameId.GOMOKU);
        expect(parsed.playerCount).assertEqual(2);
      }
    });

    it('rejectsMissingCredentialUnknownGameAndBadPlayerCount', 0, () => {
      expect(RoomInviteService.parse('tabletopparty://room?code=ABC123&game=gomoku&players=2&token=') === null)
        .assertTrue();
      expect(RoomInviteService.parse(
        'tabletopparty://room?code=ABC123&game=unknown&players=2&token=temporary-credential') === null)
        .assertTrue();
      expect(RoomInviteService.parse(
        'tabletopparty://room?code=ABC123&game=landlord&players=9&token=temporary-credential') === null)
        .assertTrue();
    });
  });
}
