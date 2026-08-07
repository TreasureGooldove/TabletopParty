/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import {
  abilityAccessCtrl,
  AbilityConstant,
  ConfigurationConstant,
  PermissionRequestResult,
  Permissions,
  UIAbility,
  Want
} from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { NearbyGameService } from '../services/NearbyGameService';
import { PartyAppStore } from '../viewmodels/PartyAppStore';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    NearbyGameService.getInstance().initialize(this.context);
    PartyAppStore.getInstance().initialize(this.context).catch(() => {
      return;
    });
    this.receiveInvite(want);
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.receiveInvite(want);
  }

  onDestroy(): void {
    NearbyGameService.getInstance().shutdown();
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
      this.requestStartupPermissions();
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }

  private receiveInvite(want: Want): void {
    if (want.uri !== undefined && want.uri.length > 0) {
      const result = PartyAppStore.getInstance().receiveInvite(want.uri);
      hilog.info(DOMAIN, 'TabletopParty', '%{public}s', result.message);
    }
  }

  private async requestStartupPermissions(): Promise<void> {
    const permissions: Permissions[] = ['ohos.permission.ACCESS_NEARLINK'];
    try {
      const result: PermissionRequestResult = await abilityAccessCtrl.createAtManager()
        .requestPermissionsFromUser(this.context, permissions);
      const granted: boolean = result.authResults.length > 0 && result.authResults[0] === 0;
      hilog.info(DOMAIN, 'TabletopParty', 'NearLink permission granted: %{public}s', granted.toString());
    } catch (error) {
      hilog.warn(DOMAIN, 'TabletopParty', 'Permission request failed: %{public}s', JSON.stringify(error));
    }
  }
}
