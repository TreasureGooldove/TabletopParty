import { ActionResult } from './GameContracts';
import { EnvelopeKind, RoomEnvelopeV3, RoomProtocolV3 } from './RoomProtocol';
import { RoomTransport, RoomTransportListener } from './RoomTransport';

export interface ReliableRoomListener {
  onReliableMessage(kind: EnvelopeKind, senderId: string, revision: number, payload: string): void;
  onReliableState(message: string): void;
}

class PendingMessage {
  public id: string;
  public chunks: RoomEnvelopeV3[];
  public attempts: number = 1;

  constructor(id: string, chunks: RoomEnvelopeV3[]) {
    this.id = id;
    this.chunks = chunks;
  }
}

class IncomingChunks {
  public id: string;
  public chunks: RoomEnvelopeV3[] = [];

  constructor(id: string) {
    this.id = id;
  }
}

export class ReliableRoomChannel implements RoomTransportListener {
  private transport: RoomTransport;
  private listener: ReliableRoomListener;
  private protocol: RoomProtocolV3 = new RoomProtocolV3();
  private pending: PendingMessage[] = [];
  private incoming: IncomingChunks[] = [];
  private receivedIds: string[] = [];
  private roomCode: string = '';
  private localPlayerId: string = '';

  constructor(transport: RoomTransport, listener: ReliableRoomListener) {
    this.transport = transport;
    this.listener = listener;
  }

  public configure(roomCode: string, localPlayerId: string): void {
    this.roomCode = roomCode;
    this.localPlayerId = localPlayerId;
  }

  public async send(kind: EnvelopeKind, revision: number, payload: string): Promise<ActionResult> {
    const messageId: string = this.localPlayerId + '-' + Date.now().toString(36) + '-' +
      Math.floor(Math.random() * 10000).toString();
    const chunks: RoomEnvelopeV3[] = this.protocol.chunk(this.roomCode, this.localPlayerId,
      messageId, revision, kind, payload);
    const pending: PendingMessage = new PendingMessage(messageId, chunks);
    this.pending.push(pending);
    return this.sendChunks(pending);
  }

  public async retryPending(): Promise<void> {
    const snapshot: PendingMessage[] = this.pending.slice();
    for (let index: number = 0; index < snapshot.length; index += 1) {
      if (snapshot[index].attempts < 4) {
        snapshot[index].attempts += 1;
        await this.sendChunks(snapshot[index]);
      } else {
        this.removePending(snapshot[index].id);
        this.listener.onReliableState('消息 ' + snapshot[index].id + ' 重试超限');
      }
    }
  }

  public onEnvelope(envelope: RoomEnvelopeV3): void {
    if (envelope.roomCode !== this.roomCode) {
      return;
    }
    if (envelope.kind === EnvelopeKind.ACK) {
      this.removePending(envelope.payload);
      return;
    }
    if (this.receivedIds.indexOf(envelope.messageId) >= 0) {
      this.sendAck(envelope.messageId, envelope.revision);
      return;
    }
    let group: IncomingChunks | null = null;
    for (let index: number = 0; index < this.incoming.length; index += 1) {
      if (this.incoming[index].id === envelope.messageId) {
        group = this.incoming[index];
      }
    }
    if (group === null) {
      group = new IncomingChunks(envelope.messageId);
      this.incoming.push(group);
    }
    let duplicateChunk: boolean = false;
    for (let index: number = 0; index < group.chunks.length; index += 1) {
      if (group.chunks[index].chunkIndex === envelope.chunkIndex) {
        duplicateChunk = true;
      }
    }
    if (!duplicateChunk) {
      group.chunks.push(envelope);
    }
    const payload: string | null = this.protocol.assemble(group.chunks);
    if (payload !== null) {
      this.rememberReceived(envelope.messageId);
      this.removeIncoming(envelope.messageId);
      this.sendAck(envelope.messageId, envelope.revision);
      this.listener.onReliableMessage(envelope.kind, envelope.senderId, envelope.revision, payload);
    }
  }

  public onTransportState(message: string): void {
    this.listener.onReliableState(message);
  }

  private async sendChunks(pending: PendingMessage): Promise<ActionResult> {
    for (let index: number = 0; index < pending.chunks.length; index += 1) {
      const result: ActionResult = await this.transport.send(pending.chunks[index]);
      if (!result.success) {
        return result;
      }
    }
    return new ActionResult(true, '消息已发送并等待确认');
  }

  private sendAck(messageId: string, revision: number): void {
    const chunks: RoomEnvelopeV3[] = this.protocol.chunk(this.roomCode, this.localPlayerId,
      'ack-' + messageId, revision, EnvelopeKind.ACK, messageId);
    if (chunks.length > 0) {
      this.transport.send(chunks[0]).catch(() => {
        return;
      });
    }
  }

  private removePending(messageId: string): void {
    for (let index: number = this.pending.length - 1; index >= 0; index -= 1) {
      if (this.pending[index].id === messageId) {
        this.pending.splice(index, 1);
      }
    }
  }

  private removeIncoming(messageId: string): void {
    for (let index: number = this.incoming.length - 1; index >= 0; index -= 1) {
      if (this.incoming[index].id === messageId) {
        this.incoming.splice(index, 1);
      }
    }
  }

  private rememberReceived(messageId: string): void {
    this.receivedIds.push(messageId);
    if (this.receivedIds.length > 256) {
      this.receivedIds.splice(0, this.receivedIds.length - 256);
    }
  }
}
