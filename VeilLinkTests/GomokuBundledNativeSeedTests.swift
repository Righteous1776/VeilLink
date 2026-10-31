import Foundation
import XCTest
@testable import VeilLink

@MainActor
final class GomokuBundledNativeSeedTests: XCTestCase {
    func testAllBundledMatchesAreVerifiedNativeGames() throws {
        let url = try XCTUnwrap(Bundle.main.url(
            forResource: GomokuBundledNativeSeed.resourceName, withExtension: "json"
        ), "The pre-trained native match archive must actually be present in the application bundle")
        let games = try GomokuBundledNativeSeed.verify(from: url)
        XCTAssertEqual(games.count, 2_000)
        XCTAssertEqual(games.reduce(0) { $0 + $1.plies.count }, 93_530)
        let uniqueSequences = Set(games.map { record in
            record.plies.map(\.action).joined(separator: ",")
        })
        XCTAssertEqual(uniqueSequences.count, 236, "Repeated games are not 2,000 novel experiences")
        let positions = Set(games.flatMap { $0.plies.map(\.position) })
        XCTAssertEqual(positions.count, 10_710)
        XCTAssertTrue(games.allSatisfy { $0.result != .unfinished })
    }

    func testModifiedPayloadCannotBePromoted() throws {
        let source = try XCTUnwrap(Bundle.main.url(
            forResource: GomokuBundledNativeSeed.resourceName, withExtension: "json"
        ))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(
            with: Data(contentsOf: source)
        ) as? [String: Any])
        var records = try XCTUnwrap(json["records"] as? [[String: Any]])
        records[0]["m"] = "AAAAAAA="
        json["records"] = records
        let corrupt = try JSONSerialization.data(withJSONObject: json)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("native-selfplay-corrupt-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        try corrupt.write(to: url, options: .atomic)
        XCTAssertThrowsError(try GomokuBundledNativeSeed.verify(from: url))
    }
}
