import { describe, expect, it } from '@ohos/hypium';
import { ContentPackV1, GameId } from '../main/ets/core/GameContracts';
import { BuiltInContent } from '../main/ets/services/BuiltInContent';
import { ContentLibrary } from '../main/ets/services/ContentLibrary';

export default function contentLibraryTest(): void {
  describe('ContentLibraryTest', () => {
    it('meetsInitialOriginalContentTargets', 0, () => {
      expect(BuiltInContent.undercoverPairs().length >= 300).assertTrue();
      expect(BuiltInContent.drawWords().length >= 300).assertTrue();
      expect(BuiltInContent.charadesWords().length >= 300).assertTrue();
      expect(BuiltInContent.truthQuestions().length >= 150).assertTrue();
      expect(BuiltInContent.dareChallenges().length >= 150).assertTrue();
      expect(BuiltInContent.werewolfSetups().length).assertEqual(7);
    });

    it('validatesVersionTypeDuplicatesAndExecutableText', 0, () => {
      const library: ContentLibrary = new ContentLibrary();
      const pack: ContentPackV1 = new ContentPackV1();
      pack.id = 'safe-1';
      pack.title = '安全画猜';
      pack.gameId = 'drawGuess';
      pack.entries = ['纸飞机', '纸飞机', '<script>alert(1)</script>', '发光的鲸鱼'];
      expect(library.importPack(pack)).assertEqual('已导入 2 条内容');
      expect(library.importPack(pack)).assertEqual('已存在相同 id 的内容包');
      const oldPack: ContentPackV1 = new ContentPackV1();
      oldPack.version = 2;
      expect(library.importPack(oldPack)).assertEqual('只支持 ContentPackV1');
    });

    it('persistsAndTogglesLocalContentPacks', 0, () => {
      const library: ContentLibrary = new ContentLibrary();
      const pack: ContentPackV1 = new ContentPackV1();
      pack.id = 'toggle-pack';
      pack.title = '开关测试';
      pack.gameId = GameId.DRAW_GUESS;
      pack.entries = ['纸飞机'];
      expect(library.importPack(pack).indexOf('已导入')).assertEqual(0);
      expect(library.togglePack(pack.id)).assertEqual('内容包已停用');
      const restored: ContentLibrary = new ContentLibrary();
      restored.restoreCustomData(library.exportCustomData());
      expect(restored.packSummaries()[0].enabled).assertFalse();
      expect(restored.summaries()[1].customCount).assertEqual(0);
    });
  });
}
