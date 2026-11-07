import Foundation
import XCTest
import VeilopolyEngine
import VeilopolyNet
@testable import VeilLink

final class VeilopolyControlIntegrationTests: XCTestCase {
    func testWorstCaseFragmentFitsExistingBLEControlLimitAndCodecRoundTrips() throws {
        let fragment = VeilopolyControlFragment(roomID: UUID().uuidString, transferID: UUID().uuidString,
            index: VeilopolyControlCodec.maximumFragments - 1, count: VeilopolyControlCodec.maximumFragments,
            bytes: Data(repeating: 255, count: VeilopolyControlCodec.fragmentBytes))
        let event = VeilControlEvent(topic: VeilopolyControlCodec.topic, payload: try JSONEncoder().encode(fragment))
        let bytes = try VeilControlEventCodec.encode(event)
        XCTAssertLessThanOrEqual(bytes.count, 2_048, "Existing BLE cap must not be raised for game traffic")
        XCTAssertEqual(try VeilControlEventCodec.decode(bytes), event)
    }
    func testApplicationRoomMetadataDoesNotRequireAnotherWireVersion() throws {
        let config = VeilopolyRoomConfiguration(roomID: UUID().uuidString, seed: 9401,
            hostIdentityID: "host", guestIdentityID: "guest")
        let packet = VeilopolyRoomPacket(roomID: config.roomID, kind: .invite, configuration: config)
        let fragments = try VeilopolyControlCodec.fragments(packet)
        var assembler = VeilopolyControlAssembler()
        var decoded: VeilopolyRoomPacket?
        for fragment in fragments {
            let event = VeilControlEvent(topic: VeilopolyControlCodec.topic, payload: try JSONEncoder().encode(fragment))
            let verified = try VeilControlEventCodec.decode(VeilControlEventCodec.encode(event))
            let received = try JSONDecoder().decode(VeilopolyControlFragment.self, from: verified.payload)
            if let complete = try assembler.ingest(received, from: "host", now: 1) { decoded = complete }
        }
        XCTAssertEqual(decoded?.configuration, config)
        XCTAssertEqual(VeilControlEvent(topic: "other.feature", payload: Data()).schemaVersion, 1)
    }
}
