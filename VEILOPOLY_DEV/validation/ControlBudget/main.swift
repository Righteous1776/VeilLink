import Foundation
import VeilopolyNet
import VeilopolyEngine

// Compile alongside the ACTUAL VeilLink/Core/VeilControlEvent.swift, not a mock
// of its limits. Synthetic data only; executable stays outside the repository.
let config = VeilopolyRoomConfiguration(roomID: "831BA512-EE4D-44AE-ABF7-005769FD2648",
 seed: 9101, hostIdentityID: String(repeating: "h", count: 128), guestIdentityID: String(repeating: "g", count: 128))
let room = try VeilopolyLiveRoom(configuration: config, localIdentityID: config.hostIdentityID)
let packets = [
 VeilopolyRoomPacket(roomID: config.roomID, kind: .invite, configuration: config),
 VeilopolyRoomPacket(roomID: config.roomID, kind: .snapshot, snapshot: GameSnapshot(room.game))
]
var maximum = 0
var tested = 0
for packet in packets {
 for fragment in try VeilopolyControlCodec.fragments(packet) {
  let payload = try JSONEncoder().encode(fragment)
  precondition(payload.count <= 1_536)
  let event = VeilControlEvent(topic: VeilopolyControlCodec.topic, payload: payload)
  let encoded = try VeilControlEventCodec.encode(event)
  precondition(encoded.count <= 2_048)
  let decoded = try VeilControlEventCodec.decode(encoded)
  precondition(decoded.payload == payload)
  maximum = max(maximum, encoded.count); tested += 1
 }
}
let worst = VeilopolyControlFragment(roomID: config.roomID, transferID: UUID().uuidString,
 index: VeilopolyControlCodec.maximumFragments - 1, count: VeilopolyControlCodec.maximumFragments,
 bytes: Data(repeating: 255, count: VeilopolyControlCodec.fragmentBytes))
let worstEvent = VeilControlEvent(topic: VeilopolyControlCodec.topic, payload: try JSONEncoder().encode(worst))
let worstBytes = try VeilControlEventCodec.encode(worstEvent)
precondition(worstBytes.count <= 2_048)
maximum = max(maximum, worstBytes.count)
print("PASS actual control-event codec: \(tested + 1) fragments, max \(maximum) bytes <= 2048; no Wire/transport edits")
