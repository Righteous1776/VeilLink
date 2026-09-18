import XCTest
@testable import VeilLink

final class AgentNavigationTests: XCTestCase {
    func testAgentRouteIsBetweenNearbyAndSettings() {
        XCTAssertEqual(SidebarSection.allCases, [.chats, .nearby, .agent, .settings])
        XCTAssertEqual(SidebarSection.agent.rawValue, "灵核")
        XCTAssertFalse(SidebarSection.agent.icon.isEmpty)
    }
}
