import Foundation

/// App-layer segmentation, NOT Wire v4 framing. A 512-byte slice leaves room
/// for JSON/base64 wrappers under the existing BLE control-event 2048-byte cap.
public struct VeilopolyControlFragment: Codable, Equatable {
 public let roomID: String
 public let transferID: String
 public let index: Int
 public let count: Int
 public let bytes: Data
 public init(roomID: String, transferID: String, index: Int, count: Int, bytes: Data) {
  self.roomID=roomID; self.transferID=transferID; self.index=index; self.count=count; self.bytes=bytes
 }
 public var isValid: Bool {
  UUID(uuidString: roomID)?.uuidString == roomID && UUID(uuidString: transferID)?.uuidString == transferID &&
  (1...VeilopolyControlCodec.maximumFragments).contains(count) && (0..<count).contains(index) &&
  !bytes.isEmpty && bytes.count <= VeilopolyControlCodec.fragmentBytes
 }
}
public enum VeilopolyControlCodec {
 public static let topic = "veilopoly.room.v1"
 public static let fragmentBytes = 512
 public static let maximumMessageBytes = 2 * 1024 * 1024
 public static let maximumFragments = maximumMessageBytes / fragmentBytes
 public static func fragments(_ packet: VeilopolyRoomPacket, transferID: String = UUID().uuidString) throws -> [VeilopolyControlFragment] {
  guard packet.isValid, UUID(uuidString: transferID)?.uuidString == transferID else { throw VeilopolyRoomError.invalidPacket }
  let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
  let data = try encoder.encode(packet)
  guard !data.isEmpty, data.count <= maximumMessageBytes else { throw VeilopolyRoomError.invalidPacket }
  let count = (data.count + fragmentBytes - 1) / fragmentBytes
  return (0..<count).map { index in
   let start = index * fragmentBytes
   return VeilopolyControlFragment(roomID: packet.roomID, transferID: transferID,
    index: index, count: count, bytes: data.subdata(in: start..<min(data.count, start + fragmentBytes)))
  }
 }
}
/// At most four in-flight bounded transfers, allowing retransmission/interleaved
/// packets. Stalled transfers expire after 300s; peer identities partition keys.
public struct VeilopolyControlAssembler {
 private struct Transfer {
  let roomID: String; let id: String; let count: Int; let began: TimeInterval
  var slices: [Int: Data] = [:]
 }
 private var pending: [String: Transfer] = [:]
 private var completed: [String] = []
 public init() {}
 public mutating func ingest(_ fragment: VeilopolyControlFragment, from peer: String,
                             now: TimeInterval) throws -> VeilopolyRoomPacket? {
  guard !peer.isEmpty, peer.utf8.count <= 128, now.isFinite, fragment.isValid else {
   throw VeilopolyRoomError.invalidPacket
  }
  pending = pending.filter { now - $0.value.began <= 300 && now >= $0.value.began }
  let key = peer + "/" + fragment.roomID + "/" + fragment.transferID
  if completed.contains(key) { return nil }
  if pending[key] == nil {
   guard pending.count < 4 else { throw VeilopolyRoomError.invalidPacket }
   pending[key] = Transfer(roomID: fragment.roomID, id: fragment.transferID, count: fragment.count, began: now)
  }
  guard var transfer = pending[key], transfer.roomID == fragment.roomID,
        transfer.count == fragment.count else { throw VeilopolyRoomError.invalidPacket }
  if let old = transfer.slices[fragment.index], old != fragment.bytes {
   pending.removeValue(forKey: key); throw VeilopolyRoomError.invalidPacket
  }
  transfer.slices[fragment.index] = fragment.bytes
  pending[key] = transfer
  guard transfer.slices.count == transfer.count else { return nil }
  pending.removeValue(forKey: key)
  var data = Data()
  for index in 0..<transfer.count {
   guard let slice = transfer.slices[index] else { throw VeilopolyRoomError.invalidPacket }
   data.append(slice)
  }
  guard data.count <= VeilopolyControlCodec.maximumMessageBytes else { throw VeilopolyRoomError.invalidPacket }
  let packet = try JSONDecoder().decode(VeilopolyRoomPacket.self, from: data)
  guard packet.isValid, packet.roomID == fragment.roomID else { throw VeilopolyRoomError.invalidPacket }
  completed.append(key); completed = Array(completed.suffix(64))
  return packet
 }
}
