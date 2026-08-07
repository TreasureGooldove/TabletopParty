import { ActionResult, TransportKind } from './GameContracts';
import { RoomEnvelopeV3 } from './RoomProtocol';

export interface RoomTransportListener {
  onEnvelope(envelope: RoomEnvelopeV3): void;
  onTransportState(message: string): void;
}

export class RoomTransportConfig {
  public roomCode: string = '';
  public localPlayerId: string = '';
  public inviteCredential: string = '';
}

export interface RoomTransport {
  kind(): TransportKind;
  startHost(config: RoomTransportConfig, listener: RoomTransportListener): Promise<ActionResult>;
  join(config: RoomTransportConfig, listener: RoomTransportListener): Promise<ActionResult>;
  send(envelope: RoomEnvelopeV3): Promise<ActionResult>;
  inviteCredential(): string;
  stop(): Promise<void>;
}

export class HotSeatTransport implements RoomTransport {
  public kind(): TransportKind {
    return TransportKind.HOT_SEAT;
  }

  public async startHost(config: RoomTransportConfig, listener: RoomTransportListener): Promise<ActionResult> {
    listener.onTransportState('本机热座已就绪');
    return new ActionResult(true, '本机热座已就绪');
  }

  public async join(config: RoomTransportConfig, listener: RoomTransportListener): Promise<ActionResult> {
    listener.onTransportState('本机席位已加入');
    return new ActionResult(true, '本机席位已加入');
  }

  public async send(envelope: RoomEnvelopeV3): Promise<ActionResult> {
    return new ActionResult(true, '本机动作已由房主引擎裁决');
  }

  public inviteCredential(): string {
    return '';
  }

  public async stop(): Promise<void> {
    return;
  }
}
