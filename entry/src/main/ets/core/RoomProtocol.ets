export enum EnvelopeKind {
  HELLO = 'hello',
  JOIN = 'join',
  ACTION = 'action',
  SNAPSHOT = 'snapshot',
  ACK = 'ack',
  ERROR = 'error'
}

export class RoomEnvelopeV3 {
  public version: string = 'TP3';
  public roomCode: string = '';
  public senderId: string = '';
  public messageId: string = '';
  public revision: number = 0;
  public kind: EnvelopeKind = EnvelopeKind.HELLO;
  public chunkIndex: number = 0;
  public chunkCount: number = 1;
  public checksum: number = 0;
  public payload: string = '';
}

export class RoomProtocolV3 {
  private static readonly MAX_PAYLOAD: number = 2800;

  public encode(envelope: RoomEnvelopeV3): string {
    return envelope.version + '|' + envelope.kind + '|' + envelope.roomCode + '|' +
      encodeURIComponent(envelope.senderId) + '|' + encodeURIComponent(envelope.messageId) + '|' +
      envelope.revision.toString() + '|' + envelope.chunkIndex.toString() + '|' +
      envelope.chunkCount.toString() + '|' + envelope.checksum.toString() + '|' +
      encodeURIComponent(envelope.payload);
  }

  public decode(text: string): RoomEnvelopeV3 | null {
    try {
      const fields: string[] = text.split('|');
      if (fields.length !== 10 || fields[0] !== 'TP3') {
        return null;
      }
      const envelope: RoomEnvelopeV3 = new RoomEnvelopeV3();
      envelope.version = fields[0];
      envelope.kind = this.kind(fields[1]);
      envelope.roomCode = fields[2];
      envelope.senderId = decodeURIComponent(fields[3]);
      envelope.messageId = decodeURIComponent(fields[4]);
      envelope.revision = this.numberValue(fields[5], 0);
      envelope.chunkIndex = this.numberValue(fields[6], 0);
      envelope.chunkCount = this.numberValue(fields[7], 1);
      envelope.checksum = this.numberValue(fields[8], 0);
      envelope.payload = decodeURIComponent(fields[9]);
      if (envelope.checksum !== this.checksum(envelope.payload)) {
        return null;
      }
      return envelope;
    } catch (error) {
      return null;
    }
  }

  public chunk(roomCode: string, senderId: string, messageId: string, revision: number,
    kind: EnvelopeKind, payload: string): RoomEnvelopeV3[] {
    const result: RoomEnvelopeV3[] = [];
    const count: number = Math.max(1, Math.ceil(payload.length / RoomProtocolV3.MAX_PAYLOAD));
    for (let index: number = 0; index < count; index += 1) {
      const envelope: RoomEnvelopeV3 = new RoomEnvelopeV3();
      envelope.roomCode = roomCode;
      envelope.senderId = senderId;
      envelope.messageId = messageId;
      envelope.revision = revision;
      envelope.kind = kind;
      envelope.chunkIndex = index;
      envelope.chunkCount = count;
      envelope.payload = payload.substring(index * RoomProtocolV3.MAX_PAYLOAD,
        Math.min(payload.length, (index + 1) * RoomProtocolV3.MAX_PAYLOAD));
      envelope.checksum = this.checksum(envelope.payload);
      result.push(envelope);
    }
    return result;
  }

  public assemble(chunks: RoomEnvelopeV3[]): string | null {
    if (chunks.length === 0 || chunks.length !== chunks[0].chunkCount) {
      return null;
    }
    const ordered: RoomEnvelopeV3[] = chunks.slice();
    ordered.sort((left: RoomEnvelopeV3, right: RoomEnvelopeV3): number => left.chunkIndex - right.chunkIndex);
    let payload: string = '';
    for (let index: number = 0; index < ordered.length; index += 1) {
      if (ordered[index].chunkIndex !== index || ordered[index].messageId !== ordered[0].messageId) {
        return null;
      }
      payload += ordered[index].payload;
    }
    return payload;
  }

  public checksum(value: string): number {
    let result: number = 2166136261;
    for (let index: number = 0; index < value.length; index += 1) {
      result ^= value.charCodeAt(index);
      result = (result * 16777619) & 0x7FFFFFFF;
    }
    return result;
  }

  private kind(value: string): EnvelopeKind {
    if (value === EnvelopeKind.JOIN) {
      return EnvelopeKind.JOIN;
    }
    if (value === EnvelopeKind.ACTION) {
      return EnvelopeKind.ACTION;
    }
    if (value === EnvelopeKind.SNAPSHOT) {
      return EnvelopeKind.SNAPSHOT;
    }
    if (value === EnvelopeKind.ACK) {
      return EnvelopeKind.ACK;
    }
    if (value === EnvelopeKind.ERROR) {
      return EnvelopeKind.ERROR;
    }
    return EnvelopeKind.HELLO;
  }

  private numberValue(value: string, fallback: number): number {
    const parsed: number = Number(value);
    return Number.isFinite(parsed) ? parsed : fallback;
  }
}
