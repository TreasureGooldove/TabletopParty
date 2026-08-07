import { describe, expect, it } from '@ohos/hypium';
import { EnvelopeKind, RoomEnvelopeV3, RoomProtocolV3 } from '../main/ets/core/RoomProtocol';

export default function roomProtocolTest(): void {
  describe('RoomProtocolV3Test', () => {
    it('roundTripsChineseAndRejectsChangedChecksum', 0, () => {
      const protocol: RoomProtocolV3 = new RoomProtocolV3();
      const chunks: RoomEnvelopeV3[] = protocol.chunk('ABC123', '玩家甲', 'm-1', 7,
        EnvelopeKind.ACTION, '落子|测试');
      const encoded: string = protocol.encode(chunks[0]);
      const decoded: RoomEnvelopeV3 | null = protocol.decode(encoded);
      expect(decoded === null).assertFalse();
      if (decoded !== null) {
        expect(decoded.payload).assertEqual('落子|测试');
        expect(decoded.revision).assertEqual(7);
      }
      expect(protocol.decode(encoded + 'broken') === null).assertTrue();
    });

    it('assemblesOutOfOrderThreeKilobyteChunks', 0, () => {
      const protocol: RoomProtocolV3 = new RoomProtocolV3();
      let payload: string = '';
      for (let index: number = 0; index < 7000; index += 1) {
        payload += (index % 10).toString();
      }
      const chunks: RoomEnvelopeV3[] = protocol.chunk('ROOM88', 'host', 'large', 11,
        EnvelopeKind.SNAPSHOT, payload);
      expect(chunks.length).assertEqual(3);
      const reordered: RoomEnvelopeV3[] = [chunks[2], chunks[0], chunks[1]];
      expect(protocol.assemble(reordered)).assertEqual(payload);
    });

    it('rejectsOldProtocolAndMissingChunks', 0, () => {
      const protocol: RoomProtocolV3 = new RoomProtocolV3();
      expect(protocol.decode('TP2|action|ROOM') === null).assertTrue();
      const chunks: RoomEnvelopeV3[] = protocol.chunk('ROOM88', 'host', 'large', 11,
        EnvelopeKind.SNAPSHOT, 'a'.repeat(6000));
      expect(protocol.assemble([chunks[0]]) === null).assertTrue();
    });
  });
}
