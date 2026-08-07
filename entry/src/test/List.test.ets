import contentLibraryTest from './ContentLibrary.test';
import gameEngineTest from './GameEngine.test';
import roomProtocolTest from './RoomProtocol.test';
import roomInviteTest from './RoomInvite.test';
import tutorialCatalogTest from './TutorialCatalog.test';

export default function testsuite(): void {
  gameEngineTest();
  roomProtocolTest();
  roomInviteTest();
  contentLibraryTest();
  tutorialCatalogTest();
}
