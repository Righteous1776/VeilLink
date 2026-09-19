import XCTest
@testable import VeilLink

final class AgentNavigationTests: XCTestCase {
    func testGameRouteIsBetweenNearbyAndAgent() {
        XCTAssertEqual(SidebarSection.allCases, [.chats, .nearby, .games, .agent, .settings])
        XCTAssertEqual(SidebarSection.games.rawValue, "游戏")
        XCTAssertFalse(SidebarSection.games.icon.isEmpty)
        XCTAssertEqual(SidebarSection.agent.rawValue, "灵核")
    }
}
