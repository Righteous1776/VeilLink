import Foundation
import XCTest
import VeilopolyEngine
@testable import VeilopolyNet

final class CurrentRoomRulesTests: XCTestCase {
 private func current() -> VeilopolyRoomConfiguration {
  .current(roomID: UUID().uuidString, seed: 20261108,
           hostIdentityID: "host", guestIdentityID: "guest")
 }
 func testNewLiveRoomUsesExactlyTheCurrentSoloRulesAndContent() throws {
  let config = current()
  let host = try VeilopolyLiveRoom(configuration: config, localIdentityID: "host")
  let guest = try VeilopolyLiveRoom(configuration: config, localIdentityID: "guest")
  let sameRules = VeilopolyCityLongEconomy.make(seed: config.seed, humanCount: 2)
  XCTAssertEqual(host.game, sameRules)
  XCTAssertEqual(guest.game, sameRules)
  XCTAssertEqual(host.game.players.map(\.cash), [25_000,25_000,25_000,25_000])
  XCTAssertEqual(host.game.banking?.reserveCash, 2_000_000)
  XCTAssertEqual(host.game.banking?.financeRuleVersion, 5)
  XCTAssertEqual(host.game.cards, VeilopolyCityLongCards.allV5)
 }
 func testLegacyRoomMetadataResumesClassicWithoutAddingARulesKey() throws {
  let old = VeilopolyRoomConfiguration(roomID: UUID().uuidString, seed: 99,
   hostIdentityID: "host", guestIdentityID: "guest")
  let data = try JSONEncoder().encode(old)
  XCTAssertNil((try JSONSerialization.jsonObject(with: data) as? [String: Any])?["rulesVersion"])
  let decoded = try JSONDecoder().decode(VeilopolyRoomConfiguration.self, from: data)
  XCTAssertEqual(decoded.effectiveRulesVersion, 1)
  XCTAssertEqual(try VeilopolyLiveRoom(configuration: decoded, localIdentityID: "host").game,
                 GameFactory.make(seed: 99, humanCount: 2))
  XCTAssertEqual(VeilopolyRoomPacket(roomID: old.roomID, kind: .invite, configuration: old).version, 1)
 }
 func testCurrentInviteCannotMasqueradeAsAnOldClientCompatibleInvite() throws {
  let config = current()
  let packet = VeilopolyRoomPacket(roomID: config.roomID, kind: .invite, configuration: config)
  XCTAssertEqual(packet.version, 2, "Legacy apps only accept application version1")
  XCTAssertTrue(packet.isValid)
  var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(packet)) as? [String: Any])
  object["version"] = 1
  let disguised = try JSONDecoder().decode(VeilopolyRoomPacket.self, from: JSONSerialization.data(withJSONObject: object))
  XCTAssertFalse(disguised.isValid)
  object["version"] = 3
  XCTAssertFalse(try JSONDecoder().decode(VeilopolyRoomPacket.self,
   from: JSONSerialization.data(withJSONObject: object)).isValid)
 }
 func testCurrentInviteSurvivesUnchangedControlFragmentsAndRuleMetadata() throws {
  let config = current()
  let invite = VeilopolyRoomPacket(roomID: config.roomID, kind: .invite, configuration: config)
  var assembler = VeilopolyControlAssembler()
  var received: VeilopolyRoomPacket?
  for fragment in try VeilopolyControlCodec.fragments(invite).reversed() {
   if let complete = try assembler.ingest(fragment, from: "host", now: 1) { received = complete }
  }
  XCTAssertEqual(received?.configuration, config)
  XCTAssertEqual(received?.version, 2)
  XCTAssertEqual(VeilopolyRoomPacket(roomID: config.roomID, kind: .accept).version, 1)
 }
 func testCurrentFinanceActionsReplayIdenticallyOnHostAndGuest() throws {
  let config = current()
  var initial = config.initialGame(); initial.turn.phase = .manage
  var host = try VeilopolyLiveRoom(configuration: config, localIdentityID: "host", restoredGame: initial)
  var guest = try VeilopolyLiveRoom(configuration: config, localIdentityID: "guest", restoredGame: initial)
  for kind in [MoveKind.stockBuy, .bankDeposit, .endTurn] {
   let move = Move(kind, player: 0, seq: host.game.nextSeq, amount: 1_000,
                   financeProduct: .demandDeposit, stockSymbol: "VTL", stockShares: 1)
   let next = try host.commitOnHost(move).get().0
   _ = try guest.acceptCommit(.init(seq: move.seq, move: move, stateHash: StateDigest.hash(next)), from: "host")
   XCTAssertEqual(host.game, guest.game)
   XCTAssertTrue(VeilopolyLiveRoom.validSnapshotState(next, configuration: config))
  }
  XCTAssertEqual(guest.game.nextSeq, 3)
 }
 func testSnapshotCannotDowngradeCurrentRulesOrInjectFinanceTermsOrCurrency() throws {
  let config = current()
  var guest = try VeilopolyLiveRoom(configuration: config, localIdentityID: "guest")
  let original = guest.game
  var variants = [GameFactory.make(seed: config.seed, humanCount: 2)]
  var bad = original; bad.banking?.financeRuleVersion = 4; variants.append(bad)
  bad = original; bad.banking?.reserveCash = 2_000_001; variants.append(bad)
  bad = original; bad.banking?.terms.loanCapsByProperties[0] += 1; variants.append(bad)
  bad = original; bad.banking?.market?.algorithmVersion = 1; variants.append(bad)
  bad = original; bad.banking = nil; variants.append(bad)
  for variant in variants {
   XCTAssertThrowsError(try guest.acceptSnapshot(GameSnapshot(variant), from: "host"))
   XCTAssertEqual(guest.game, original)
  }
 }
 func testUnknownRoomRulesFailBeforeCreatingAGame() {
  let config = VeilopolyRoomConfiguration(roomID: UUID().uuidString, seed: 1,
   hostIdentityID: "host", guestIdentityID: "guest", rulesVersion: 6)
  XCTAssertFalse(config.isValid)
  XCTAssertThrowsError(try VeilopolyLiveRoom(configuration: config, localIdentityID: "host"))
 }
 func testLongestValidCurrentInviteFitsUnknownRoomAssemblyBudget() throws {
  let config = VeilopolyRoomConfiguration.current(roomID: UUID().uuidString, seed: .max,
   hostIdentityID: String(repeating: "h", count: 128), guestIdentityID: String(repeating: "g", count: 128))
  let fragments = try VeilopolyControlCodec.fragments(.init(roomID: config.roomID,
   kind: .invite, configuration: config))
  XCTAssertLessThanOrEqual(fragments.count, 4, "Host bridge bounds unknown rooms at four fragments")
 }
 func testCurrentGuestFinanceOrderUsesHostAuthorityAndSameResult() throws {
  let config = current()
  var initial = config.initialGame(); initial.turn.player = 1; initial.turn.phase = .manage
  var host = try VeilopolyLiveRoom(configuration: config, localIdentityID: "host", restoredGame: initial)
  var guest = try VeilopolyLiveRoom(configuration: config, localIdentityID: "guest", restoredGame: initial)
  let order = Move(.stockBuy, player: 1, seq: 0, stockSymbol: "VTL", stockShares: 1)
  try host.validateProposal(order, from: "guest")
  XCTAssertThrowsError(try guest.validateProposal(order, from: "host"))
  let committed = try host.commitOnHost(order).get().0
  _ = try guest.acceptCommit(.init(seq: 0, move: order, stateHash: StateDigest.hash(committed)), from: "host")
  XCTAssertEqual(guest.game, host.game)
  XCTAssertEqual(guest.game.banking?.financeRuleVersion, 5)
 }
 func testCurrentRoomEncodedSnapshotAndResumeKeepV5InsteadOfClassic() throws {
  let config = current()
  let initial = try VeilopolyLiveRoom(configuration: config, localIdentityID: "host").game
  let bytes = try JSONEncoder().encode(GameSnapshot(initial))
  let snapshot = try JSONDecoder().decode(GameSnapshot.self, from: bytes)
  var guest = try VeilopolyLiveRoom(configuration: config, localIdentityID: "guest")
  try guest.acceptSnapshot(snapshot, from: "host")
  let restored = try VeilopolyLiveRoom(configuration: config, localIdentityID: "guest", restoredGame: snapshot.game)
  XCTAssertEqual(restored.game, initial)
  XCTAssertEqual(guest.game, initial)
 }
}
