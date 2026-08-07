import { describe, expect, it } from '@ohos/hypium';
import { GameDefinition } from '../main/ets/core/GameContracts';
import { GameCatalog } from '../main/ets/games/GameCatalog';
import { TutorialCatalog, TutorialStep } from '../main/ets/services/TutorialCatalog';

export default function tutorialCatalogTest(): void {
  describe('TutorialCatalogTest', () => {
    it('teachesEveryPlayableGameWithValidExercises', 0, () => {
      const games: GameDefinition[] = GameCatalog.all();
      expect(games.length).assertEqual(15);
      for (let gameIndex: number = 0; gameIndex < games.length; gameIndex += 1) {
        const steps: TutorialStep[] = TutorialCatalog.steps(games[gameIndex].id);
        expect(steps.length >= 3).assertTrue();
        for (let stepIndex: number = 0; stepIndex < steps.length; stepIndex += 1) {
          expect(steps[stepIndex].title.length > 0).assertTrue();
          expect(steps[stepIndex].explanation.length > 0).assertTrue();
          expect(steps[stepIndex].options.length >= 2).assertTrue();
          expect(steps[stepIndex].correctIndex >= 0).assertTrue();
          expect(steps[stepIndex].correctIndex < steps[stepIndex].options.length).assertTrue();
        }
      }
    });
  });
}
