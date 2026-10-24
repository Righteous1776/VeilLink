import XCTest
@testable import VeilLink

final class VeilRareLabEngineTests: XCTestCase {
    func testFortyUniqueOperatorsAndAllSampleRuns() throws {
        XCTAssertEqual(VeilRareLab.catalog.count, 40)
        XCTAssertEqual(Set(VeilRareLab.catalog.map(\.id)).count, 40)
        for item in VeilRareLab.catalog {
            let output = try VeilRareLab.run(id: item.id, json: VeilRareLab.sample(for: item.id))
            XCTAssertFalse(output.isEmpty, "Missing sample output for \(item.id)")
        }
    }
    func testTopologyHasCriticalArticulationAndBridge() throws {
        let raw = #"{"edges":[[0,1],[1,2],[2,3],[0,4],[4,2]]}"#
        XCTAssertTrue(try VeilRareLab.run(id: 8, json: raw).contains("2"))
        XCTAssertTrue(try VeilRareLab.run(id: 9, json: raw).contains("2-3"))
    }
    func testCanDetectLossBurstsAndAcknowledgementHoles() throws {
        let raw = #"{"expected":[0,1,2,3,4,5,6],"received":[0,3,6],"acks":[10,11,13]}"#
        XCTAssertTrue(try VeilRareLab.run(id: 11, json: raw).contains("2 块"))
        XCTAssertTrue(try VeilRareLab.run(id: 12, json: raw).contains("1 个"))
    }
    func testSignerChangeDoesNotRebuildKeys() throws {
        let raw = #"{"oldGroup":"TEAM_A.shared","newGroup":"TEAM_B.shared"}"#
        let output = try VeilRareLab.run(id: 23, json: raw)
        XCTAssertTrue(output.contains("变更"))
        XCTAssertTrue(output.contains("不能据此重建数据库密钥"))
    }
    func testTouchCoverageDiagnosticsAreAdvisory() throws {
        let raw = #"{"phases":["down","move","cancel","down","up"],"touchGrid":[[8,8],[0,2]],"overlays":[{"decorative":true,"visible":true,"hittable":true}]}"#
        XCTAssertTrue(try VeilRareLab.run(id: 32, json: raw).contains("50.0%"))
        XCTAssertTrue(try VeilRareLab.run(id: 33, json: raw).contains("1,0"))
        XCTAssertTrue(try VeilRareLab.run(id: 34, json: raw).contains("1 层"))
    }
    func testRejectsMaliciousAndOversizedPayloads() {
        XCTAssertThrowsError(try VeilRareLab.run(id: 40, json: "{bad"))
        XCTAssertThrowsError(try VeilRareLab.run(id: 41, json: "{}"))
        XCTAssertThrowsError(try VeilRareLab.run(id: 1, json: String(repeating: "x", count: 64_001)))
        XCTAssertThrowsError(try VeilRareLab.run(id: 8, json: #"{"edges":[[1]]}"#))
    }
    func testHysteresisAndFiniteRateAnalysis() throws {
        XCTAssertTrue(try VeilRareLab.run(id: 7, json: VeilRareLab.sample(for: 7)).contains("状态变更"))
        XCTAssertThrowsError(try VeilRareLab.run(id: 7, json: #"{"rssi":[-70],"thresholdIn":-90,"thresholdOut":-60}"#))
        XCTAssertTrue(try VeilRareLab.run(id: 17, json: VeilRareLab.sample(for: 17)).contains("吞吐"))
    }
    func testAllSimulationsAreDeterministic() throws {
        for item in VeilRareLab.catalog {
            let sample = VeilRareLab.sample(for: item.id)
            XCTAssertEqual(try VeilRareLab.run(id: item.id, json: sample), try VeilRareLab.run(id: item.id, json: sample))
        }
    }
}