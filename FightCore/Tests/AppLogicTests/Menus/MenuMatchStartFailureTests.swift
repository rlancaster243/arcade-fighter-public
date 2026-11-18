import AppLogic
import XCTest

final class MenuMatchStartFailureTests: XCTestCase {
  @MainActor
    func testAbortFailedMatchStartSurfacesAlertAndLeavesMatch() {
        var next = MenuShellState(screen: .inMatch(MatchSetup(
            mode: .versus,
            p1: FighterPick(rosterIndex: 0, id: "greybox"),
            p2: FighterPick(rosterIndex: 0, id: "greybox")
        )))
        MenuReducer.abortFailedMatchStart(state: &next, message: "stage stage2 has no bounds")
        guard case .mainMenu = next.screen else {
            return XCTFail("expected main menu")
        }
        XCTAssertEqual(next.alertMessage, "stage stage2 has no bounds")
    }
}