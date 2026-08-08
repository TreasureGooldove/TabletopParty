import { abilityAccessCtrl, common, PermissionRequestResult, Permissions } from '@kit.AbilityKit';
import { uniformTypeDescriptor } from '@kit.ArkData';
import { window } from '@kit.ArkUI';
import { advertising, constant, dataTransfer, manager, scan } from '@kit.NearLinkKit';
import { harmonyShare, systemShare } from '@kit.ShareKit';
import { ActionResult, GameId } from '../core/GameContracts';
import { util } from '@kit.ArkTS';
import { RoomInvite, RoomInviteService } from './RoomInviteService';

export interface NearbyDataListener {
  onNearLinkData(address: string, text: string): void;
  onNearLinkState(message: string): void;
}

export class NearbyRoomInfo {
  public address: string = '';
  public roomCode: string = '';
  public deviceName: string = '';
  public signal: number = 0;
}

export class NearbyGameService {
  private static instance: NearbyGameService = new NearbyGameService();
  private static readonly MANUFACTURER_ID: number = 2026;
  private static readonly SERVICE_UUID: string = 'A14A8CB0-8CE2-4DC9-BFB7-202600000001';
  private context: common.UIAbilityContext | null = null;
  private roomCode: string = '';
  private gameId: GameId = GameId.UNDERCOVER;
  private playerCount: number = 2;
  private inviteToken: string = '';
  private advertisingId: number = -1;
  private knockRegistered: boolean = false;
  private scanRegistered: boolean = false;
  private portRegistered: boolean = false;
  private knockCapability: harmonyShare.SendCapabilityRegistry | null = null;
  private rooms: NearbyRoomInfo[] = [];
  private dataListener: NearbyDataListener | null = null;

  private readDataCallback = (params: dataTransfer.DataParams): void => {
    if (params.uuid !== NearbyGameService.SERVICE_UUID || this.dataListener === null) {
      return;
    }
    const decoder: util.TextDecoder = util.TextDecoder.create('utf-8');
    this.dataListener.onNearLinkData(params.address, decoder.decodeToString(new Uint8Array(params.data)));
  };

  private connectionCallback = (result: dataTransfer.ConnectionResult): void => {
    if (result.uuid === NearbyGameService.SERVICE_UUID && this.dataListener !== null) {
      this.dataListener.onNearLinkState('星闪连接状态：' + result.state.toString());
    }
  };

  private knockCallback = (target: harmonyShare.SharableTarget): void => {
    const link: string = this.inviteLink();
    const sharedData: systemShare.SharedData = new systemShare.SharedData({
      utd: uniformTypeDescriptor.UniformDataType.HYPERLINK,
      content: link,
      title: '桌游派对 · ' + this.roomCode,
      description: '碰一碰加入近场房间'
    });
    target.share(sharedData).catch(() => {
      return;
    });
  };

  private scanCallback = (results: scan.ScanResults[]): void => {
    const nextRooms: NearbyRoomInfo[] = this.rooms.slice();
    for (let index: number = 0; index < results.length; index += 1) {
      const bytes: Uint8Array = new Uint8Array(results[index].data);
      const code: string = this.decodeRoomCode(bytes);
      if (code.length !== 6) {
        continue;
      }
      let exists: boolean = false;
      for (let roomIndex: number = 0; roomIndex < nextRooms.length; roomIndex += 1) {
        if (nextRooms[roomIndex].address === results[index].address) {
          nextRooms[roomIndex].roomCode = code;
          nextRooms[roomIndex].signal = results[index].rssi;
          exists = true;
        }
      }
      if (!exists) {
        const room: NearbyRoomInfo = new NearbyRoomInfo();
        room.address = results[index].address;
        room.roomCode = code;
        room.deviceName = results[index].deviceName.length > 0 ? results[index].deviceName : '附近星闪设备';
        room.signal = results[index].rssi;
        nextRooms.push(room);
      }
    }
    this.rooms = nextRooms;
  };

  public static getInstance(): NearbyGameService {
    return NearbyGameService.instance;
  }

  public initialize(context: common.UIAbilityContext): void {
    this.context = context;
  }

  public configure(roomCode: string, gameId: GameId, playerCount: number): void {
    this.roomCode = roomCode;
    this.gameId = gameId;
    this.playerCount = playerCount;
  }

  public setInviteCredential(value: string): void {
    this.inviteToken = value;
  }

  public hasInviteCredential(): boolean {
    return this.inviteToken.length >= 16;
  }

  public inviteLink(): string {
    const invite: RoomInvite = new RoomInvite();
    invite.roomCode = this.roomCode;
    invite.gameId = this.gameId;
    invite.playerCount = this.playerCount;
    invite.credential = this.inviteToken;
    return RoomInviteService.create(invite);
  }

  public async shareRoom(): Promise<ActionResult> {
    if (this.context === null || !this.hasInviteCredential()) {
      return new ActionResult(false, '请先开启同一 Wi-Fi 加密通道');
    }
    try {
      const data: systemShare.SharedData = new systemShare.SharedData({
        utd: uniformTypeDescriptor.UniformDataType.HYPERLINK,
        content: this.inviteLink(),
        title: '桌游派对 · ' + this.roomCode,
        description: '加入身边好友的近场房间'
      });
      const controller: systemShare.ShareController = new systemShare.ShareController(data);
      await controller.show(this.context, {
        selectionMode: systemShare.SelectionMode.SINGLE
      });
      return new ActionResult(true, '已打开系统分享面板');
    } catch (error) {
      return new ActionResult(false, '系统分享暂不可用，可复制房间码邀请');
    }
  }

  public setDataListener(listener: NearbyDataListener | null): void {
    this.dataListener = listener;
  }

  public async connect(address: string): Promise<ActionResult> {
    const portResult: ActionResult = this.preparePort();
    if (!portResult.success) {
      return portResult;
    }
    try {
      const params: dataTransfer.ConnectionParams = {
        address: address,
        uuid: NearbyGameService.SERVICE_UUID,
        mtu: 3072,
        transferMode: dataTransfer.TransferMode.RELIABLE
      };
      await dataTransfer.connect(params);
      return new ActionResult(true, '星闪可靠连接已建立');
    } catch (error) {
      return new ActionResult(false, '星闪配对失败，可改用 Wi‑Fi 或热座');
    }
  }

  public async sendEnvelope(address: string, text: string): Promise<ActionResult> {
    if (text.length > 3072) {
      return new ActionResult(false, '星闪单片数据超过 3 KB，请先分片');
    }
    try {
      const encoder: util.TextEncoder = util.TextEncoder.create('utf-8');
      const bytes: Uint8Array = encoder.encodeInto(text);
      const params: dataTransfer.DataParams = {
        address: address,
        uuid: NearbyGameService.SERVICE_UUID,
        data: bytes.buffer
      };
      await dataTransfer.writeData(params);
      return new ActionResult(true, '星闪动作已可靠发送');
    } catch (error) {
      return new ActionResult(false, '星闪动作发送失败');
    }
  }

  public roomResults(): NearbyRoomInfo[] {
    return this.rooms.slice();
  }

  public nearLinkState(): string {
    try {
      return manager.getState() === manager.NearlinkState.STATE_ON ? '星闪已开启' : '请在系统设置开启星闪';
    } catch (error) {
      return '当前设备未提供星闪能力';
    }
  }

  public async enableKnock(): Promise<ActionResult> {
    if (this.context === null || this.roomCode.length !== 6 || !this.hasInviteCredential()) {
      return new ActionResult(false, '请先创建房间');
    }
    if (this.knockRegistered) {
      return new ActionResult(true, '碰一碰邀请已在房间前台监听');
    }
    try {
      const mainWindow: window.Window = await window.getLastWindow(this.context);
      const capability: harmonyShare.SendCapabilityRegistry = {
        windowId: mainWindow.getWindowProperties().id,
        sendOnly: true
      };
      harmonyShare.on('knockShare', capability, this.knockCallback);
      this.knockCapability = capability;
      this.knockRegistered = true;
      return new ActionResult(true, '碰一碰已开启，请保持房间页在前台');
    } catch (error) {
      return new ActionResult(false, '碰一碰注册失败，可使用系统分享或房间码');
    }
  }

  public async startBroadcast(): Promise<ActionResult> {
    if (this.roomCode.length !== 6) {
      return new ActionResult(false, '请先创建房间');
    }
    if (!await this.ensurePermission()) {
      return new ActionResult(false, '未获得星闪权限，仍可使用碰一碰、Wi‑Fi 或热座');
    }
    const portResult: ActionResult = this.preparePort();
    if (!portResult.success) {
      return portResult;
    }
    try {
      if (manager.getState() !== manager.NearlinkState.STATE_ON) {
        return new ActionResult(false, '请先在系统设置开启星闪');
      }
      if (this.advertisingId >= 0) {
        return new ActionResult(true, '星闪房间正在发布');
      }
      const bytes: Uint8Array = this.encodeInvite();
      const manufacturerData: advertising.ManufacturerData = {
        manufacturerId: NearbyGameService.MANUFACTURER_ID,
        manufacturerData: bytes.buffer
      };
      const settings: advertising.AdvertisingSettings = {
        interval: 5000,
        power: advertising.TxPowerMode.ADV_TX_POWER_LOW
      };
      const data: advertising.AdvertisingData = {
        manufacturerData: [manufacturerData],
        includeDeviceName: true
      };
      const params: advertising.AdvertisingParams = {
        advertisingSettings: settings,
        advertisingData: data
      };
      this.advertisingId = await advertising.startAdvertising(params);
      return new ActionResult(true, '星闪房间已发布，可被附近设备发现');
    } catch (error) {
      return new ActionResult(false, '星闪发布失败，仍可使用碰一碰、Wi‑Fi 或热座');
    }
  }

  public async scanRooms(): Promise<ActionResult> {
    this.rooms = [];
    if (!await this.ensurePermission()) {
      return new ActionResult(false, '未获得星闪权限，请改用房间码或系统分享');
    }
    const portResult: ActionResult = this.preparePort();
    if (!portResult.success) {
      return portResult;
    }
    try {
      if (manager.getState() !== manager.NearlinkState.STATE_ON) {
        return new ActionResult(false, '请先在系统设置开启星闪');
      }
      if (!this.scanRegistered) {
        scan.on('deviceFound', this.scanCallback);
        this.scanRegistered = true;
      }
      const filter: scan.ScanFilters = { manufacturerId: NearbyGameService.MANUFACTURER_ID };
      const options: scan.ScanOptions = { scanMode: scan.ScanMode.SCAN_MODE_LOW_POWER, duration: 10 };
      await scan.startScan([filter], options);
      return new ActionResult(true, '正在扫描附近星闪房间，持续 10 秒');
    } catch (error) {
      return new ActionResult(false, '星闪扫描不可用，请改用房间码或系统分享');
    }
  }

  public async shutdown(): Promise<void> {
    if (this.knockRegistered) {
      try {
        if (this.knockCapability !== null) {
          harmonyShare.off('knockShare', this.knockCapability, this.knockCallback);
        }
      } catch (error) {
        // 页面结束时忽略已经被系统释放的监听。
      }
      this.knockRegistered = false;
      this.knockCapability = null;
    }
    if (this.scanRegistered) {
      try {
        await scan.stopScan();
        scan.off('deviceFound', this.scanCallback);
      } catch (error) {
        // 扫描可能已自动结束。
      }
      this.scanRegistered = false;
    }
    if (this.advertisingId >= 0) {
      try {
        await advertising.stopAdvertising(this.advertisingId);
      } catch (error) {
        // 广播可能已被系统回收。
      }
      this.advertisingId = -1;
    }
    if (this.portRegistered) {
      try {
        dataTransfer.off('readData', this.readDataCallback);
        dataTransfer.off('connectionStateChanged', this.connectionCallback);
        dataTransfer.destroyPort(NearbyGameService.SERVICE_UUID);
      } catch (error) {
        // 数据端口可能已经释放。
      }
      this.portRegistered = false;
    }
  }

  private preparePort(): ActionResult {
    if (this.portRegistered) {
      return new ActionResult(true, '星闪可靠数据端口已开启');
    }
    try {
      dataTransfer.createPort(NearbyGameService.SERVICE_UUID);
      dataTransfer.on('readData', this.readDataCallback);
      dataTransfer.on('connectionStateChanged', this.connectionCallback);
      this.portRegistered = true;
      return new ActionResult(true, '星闪可靠数据端口已开启');
    } catch (error) {
      return new ActionResult(false, '无法创建星闪可靠数据端口');
    }
  }

  private async ensurePermission(): Promise<boolean> {
    if (this.context === null) {
      return false;
    }
    try {
      const permissions: Permissions[] = ['ohos.permission.ACCESS_NEARLINK'];
      const result: PermissionRequestResult = await abilityAccessCtrl.createAtManager()
        .requestPermissionsFromUser(this.context, permissions);
      return result.authResults.length > 0 && result.authResults[0] === 0;
    } catch (error) {
      return false;
    }
  }

  private encodeInvite(): Uint8Array {
    const bytes: Uint8Array = new Uint8Array(8);
    for (let index: number = 0; index < 6; index += 1) {
      bytes[index] = this.roomCode.charCodeAt(index);
    }
    bytes[6] = this.gameCode(this.gameId);
    bytes[7] = Math.max(2, Math.min(12, this.playerCount));
    return bytes;
  }

  private decodeRoomCode(bytes: Uint8Array): string {
    for (let start: number = 0; start + 7 < bytes.length; start += 1) {
      let code: string = '';
      let valid: boolean = true;
      for (let index: number = 0; index < 6; index += 1) {
        const value: number = bytes[start + index];
        const accepted: boolean = value >= 48 && value <= 57 || value >= 65 && value <= 90;
        if (!accepted) {
          valid = false;
          break;
        }
        code += String.fromCharCode(value);
      }
      if (valid) {
        return code;
      }
    }
    return '';
  }

  private gameCode(id: GameId): number {
    const ids: GameId[] = [GameId.UNDERCOVER, GameId.LANDLORD, GameId.CHINESE_CHESS, GameId.JUNQI,
      GameId.WEREWOLF, GameId.COLOR_CLASH, GameId.GOMOKU, GameId.REVERSI, GameId.LUDO,
      GameId.SICHUAN_MAHJONG, GameId.GUANDAN, GameId.DRAW_GUESS];
    const index: number = ids.indexOf(id);
    return index < 0 ? 1 : index + 1;
  }
}
