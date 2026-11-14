#if os(iOS) && canImport(SpriteKit)
import Foundation
import XCTest
import VeilopolyNet
@testable import VeilopolyUI

@MainActor
final class FlightRecorderPrivacyTests: XCTestCase {
    func testGameLifecycleEmitsOnlyPrimitiveStructuralMetadata() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("veilopoly-flight-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let events = NSMutableArray()
        let observer = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("Veilopoly.FlightRecorder.v1"),
            object: nil, queue: nil
        ) { notice in
            if let fields = notice.userInfo { events.add(fields) }
        }
        defer { NotificationCenter.default.removeObserver(observer) }
        let config = VeilopolyRoomConfiguration(
            roomID: UUID().uuidString, seed: 8107,
            hostIdentityID: "host-private", guestIdentityID: "guest-private"
        )
        let game = try GameSessionModel(
            multiplayer: config, localIdentityID: "host-private",
            saveDirectory: dir
        ) { _ in }
        XCTAssertEqual(game.game.nextSeq, 0)

        let evidence = try XCTUnwrap(
            events.compactMap { $0 as? [AnyHashable: Any] }
                .first { ($0["phase"] as? String) == "match.new" }
        )
        XCTAssertEqual(Set(evidence.keys.compactMap { $0 as? String }), Set([
            "phase", "next_seq", "player", "turn_phase", "multiplayer"
        ]))
        XCTAssertEqual(evidence["next_seq"] as? Int, 0)
        XCTAssertEqual(evidence["multiplayer"] as? Bool, true)
        let joined = evidence.values.map { String(describing: $0) }.joined(separator: "|")
        XCTAssertFalse(joined.contains(config.roomID))
        XCTAssertFalse(joined.contains("host-private"))
        XCTAssertFalse(joined.contains("guest-private"))
    }
}
#endif