#if os(iOS) && canImport(SpriteKit)
import Foundation
import XCTest
import VeilopolyEngine
import VeilopolyNet
import VeilopolyPersistence
@testable import VeilopolyUI

@MainActor
final class LiveGameSessionTests: XCTestCase {
 private func fixture() throws -> (VeilopolyRoomConfiguration, URL) {
  let config = VeilopolyRoomConfiguration(roomID: UUID().uuidString, seed: 9201,
   hostIdentityID: "host", guestIdentityID: "guest")
  let dir = FileManager.default.temporaryDirectory.appendingPathComponent("veilopoly-live-" + UUID().uuidString)
  return (config, dir)
 }
 func testGuestProposesWithoutExecutingOrWritingAnotherSeat() throws {
  let (config, dir) = try fixture(); defer { try? FileManager.default.removeItem(at: dir) }
  let store = try VeilopolySaveStore(directory: dir)
  var initial = GameFactory.make(seed: config.seed, humanCount: 2)
  initial.turn.player = 1; initial.turn.phase = .manage
  _ = try store.save(initial, gameID: config.roomID, mode: .multiplayerGuest)
  var sent: [VeilopolyRoomPacket] = []
  let guest = try GameSessionModel(multiplayer: config, localIdentityID: "guest", saveDirectory: dir) { sent.append($0) }
  guest.setNetworkAvailability(true, message: "test")
  guest.perform(.endTurn)
  XCTAssertTrue(guest.awaitingHost)
  XCTAssertEqual(guest.game, initial)
  XCTAssertEqual(sent.first?.kind, .proposal)
  XCTAssertEqual(sent.first?.proposal?.player, 1)
  guest.perform(.endTurn)
  XCTAssertEqual(sent.count, 1, "Pending request cannot be double-submitted")
 }
 func testHostCommitsRemoteProposalAndGuestReplaysExactlyOnce() throws {
  let (config, dir) = try fixture(); defer { try? FileManager.default.removeItem(at: dir) }
  let store = try VeilopolySaveStore(directory: dir)
  var initial = GameFactory.make(seed: config.seed, humanCount: 2)
  initial.turn.player = 1; initial.turn.phase = .manage
  for mode in [VeilopolySaveMode.multiplayerHost, .multiplayerGuest] {
   _ = try store.save(initial, gameID: config.roomID, mode: mode)
  }
  var hostPackets: [VeilopolyRoomPacket] = []
  let host = try GameSessionModel(multiplayer: config, localIdentityID: "host", saveDirectory: dir) { hostPackets.append($0) }
  let guest = try GameSessionModel(multiplayer: config, localIdentityID: "guest", saveDirectory: dir) { _ in }
  host.setNetworkAvailability(true, message: "test")
  host.receiveNetworkPacket(.init(roomID: config.roomID, kind: .proposal,
   proposal: Move(.endTurn, player: 1, seq: 0)), from: "guest")
  let committed = try XCTUnwrap(hostPackets.first { $0.kind == .commit })
  guest.receiveNetworkPacket(committed, from: "host")
  guest.receiveNetworkPacket(committed, from: "host")
  XCTAssertEqual(guest.game.nextSeq, 1)
  XCTAssertEqual(StateDigest.hash(guest.game), StateDigest.hash(host.game))
  XCTAssertEqual(try store.load(gameID: config.roomID, mode: .multiplayerGuest)?.game.nextSeq, 1)
 }
 func testGuestCannotRunMarketClockAndHostTicksRemoteHumanTurn() throws {
  let (config, dir) = try fixture(); defer { try? FileManager.default.removeItem(at: dir) }
  let store = try VeilopolySaveStore(directory: dir)
  var initial = GameFactory.make(seed: config.seed, humanCount: 2)
  initial.turn.player = 1; initial.turn.phase = .manage
  for mode in [VeilopolySaveMode.multiplayerHost, .multiplayerGuest] {
   _ = try store.save(initial, gameID: config.roomID, mode: mode)
  }
  let host = try GameSessionModel(multiplayer: config, localIdentityID: "host", saveDirectory: dir) { _ in }
  let guest = try GameSessionModel(multiplayer: config, localIdentityID: "guest", saveDirectory: dir) { _ in }
  host.setNetworkAvailability(true, message: "test"); guest.setNetworkAvailability(true, message: "test")
  guest.advanceStockMarket()
  XCTAssertEqual(guest.game.nextSeq, 0)
  host.advanceStockMarket()
  XCTAssertEqual(host.game.nextSeq, 1)
 }
 func testMissingHostSaveNeverSilentlyRestartsAResumedRoom() throws {
  let (config, dir) = try fixture(); defer { try? FileManager.default.removeItem(at: dir) }
  let host = try GameSessionModel(multiplayer: config, localIdentityID: "host",
   requiresExistingSave: true, saveDirectory: dir) { _ in }
  host.setNetworkAvailability(true, message: "test")
  host.perform(.rollDice)
  XCTAssertFalse(host.networkReady)
  XCTAssertEqual(host.game.nextSeq, 0)
  XCTAssertNil(try VeilopolySaveStore(directory: dir).load(gameID: config.roomID, mode: .multiplayerHost))
 }
 func testSnapshotCancelsOldAnimationWithoutRepeatingLogicalRoll() throws {
  let (config, dir) = try fixture(); defer { try? FileManager.default.removeItem(at: dir) }
  var host = try VeilopolyLiveRoom(configuration: config, localIdentityID: "host")
  let move = Move(.rollDice, player: 0, seq: 0)
  let next = try host.commitOnHost(move).get().0
  let guest = try GameSessionModel(multiplayer: config, localIdentityID: "guest", saveDirectory: dir) { _ in }
  guest.receiveNetworkPacket(.init(roomID: config.roomID, kind: .commit,
   committed: .init(seq: 0, move: move, stateHash: StateDigest.hash(next))), from: "host")
  guest.receiveNetworkPacket(.init(roomID: config.roomID, kind: .snapshot, snapshot: GameSnapshot(next)), from: "host")
  guest.fastForward()
  XCTAssertEqual(guest.game.nextSeq, 1)
  XCTAssertEqual(guest.game.rngCounter, next.rngCounter)
 }
 func testCommittedStateIsSavedWhileGuestStillPresentsEarlierAnimation() throws {
  let (config, dir) = try fixture(); defer { try? FileManager.default.removeItem(at: dir) }
  var host = try VeilopolyLiveRoom(configuration: config, localIdentityID: "host")
  let guest = try GameSessionModel(multiplayer: config, localIdentityID: "guest", saveDirectory: dir) { _ in }
  for kind in [MoveKind.rollDice, .applyMovement] {
   let move = Move(kind, player: 0, seq: host.game.nextSeq)
   let next = try host.commitOnHost(move).get().0
   guest.receiveNetworkPacket(.init(roomID: config.roomID, kind: .commit,
    committed: .init(seq: move.seq, move: move, stateHash: StateDigest.hash(next))), from: "host")
  }
  XCTAssertEqual(guest.game.nextSeq, 1, "Presentation is still showing the first committed command")
  let stored = try VeilopolySaveStore(directory: dir).load(gameID: config.roomID, mode: .multiplayerGuest)
  XCTAssertEqual(stored?.game.nextSeq, 2, "Durability follows logical authority, not delayed animation")
 }
 func testHostLifecycleRequiresFreshPeerStatusAfterBackground() throws {
  let (config, dir) = try fixture(); defer { try? FileManager.default.removeItem(at: dir) }
  var sent: [VeilopolyRoomPacket] = []
  let host = try GameSessionModel(multiplayer: config, localIdentityID: "host", saveDirectory: dir) {
   sent.append($0)
  }
  host.setNetworkAvailability(true, message: "initial matching status")
  XCTAssertTrue(host.networkReady)
  host.setNetworkForeground(false)
  XCTAssertFalse(host.networkReady)
  host.setNetworkAvailability(true, message: "stale bridge callback")
  XCTAssertFalse(host.networkReady, "Background state cannot be reopened by a stale callback")
  host.receiveNetworkPacket(.init(roomID: config.roomID, kind: .status,
   nextSeq: host.game.nextSeq, stateHash: StateDigest.hash(host.game)), from: "guest")
  host.perform(.rollDice)
  XCTAssertEqual(host.game.nextSeq, 0, "Background host must not roll")
  host.setNetworkForeground(true)
  XCTAssertFalse(host.networkReady, "Returning to foreground requires fresh matching peer status")
  XCTAssertTrue(sent.contains(where: { $0.kind == .snapshot }), "Host requests resynchronization")
  host.receiveNetworkPacket(.init(roomID: config.roomID, kind: .status,
   nextSeq: host.game.nextSeq, stateHash: StateDigest.hash(host.game)), from: "guest")
  XCTAssertTrue(host.networkReady)
  host.perform(.rollDice)
  XCTAssertGreaterThan(host.game.nextSeq, 0)
 }
 func testBackgroundDoesNotResumeFromIncomingStatusOrExecuteAnotherRoll() throws {
  let (config, dir) = try fixture(); defer { try? FileManager.default.removeItem(at: dir) }
  let host = try GameSessionModel(multiplayer: config, localIdentityID: "host", saveDirectory: dir) { _ in }
  host.setNetworkAvailability(true, message: "test")
  host.setNetworkForeground(false)
  host.receiveNetworkPacket(.init(roomID: config.roomID, kind: .status,
   nextSeq: host.game.nextSeq, stateHash: StateDigest.hash(host.game)), from: "guest")
  host.perform(.rollDice)
  XCTAssertFalse(host.networkReady)
  XCTAssertEqual(host.game.nextSeq, 0)
 }
 func testPriceTickIsNotMistakenForConfirmationOfGuestOrder() throws {
  let (config, dir) = try fixture(); defer { try? FileManager.default.removeItem(at: dir) }
  var initial = GameFactory.make(seed: config.seed, humanCount: 2)
  initial.turn.player = 1; initial.turn.phase = .manage
  _ = try VeilopolySaveStore(directory: dir).save(initial, gameID: config.roomID, mode: .multiplayerGuest)
  var host = try VeilopolyLiveRoom(configuration: config, localIdentityID: "host", restoredGame: initial)
  let guest = try GameSessionModel(multiplayer: config, localIdentityID: "guest", saveDirectory: dir) { _ in }
  guest.setNetworkAvailability(true, message: "test")
  guest.perform(.stockBuy, stockSymbol: "VTL", stockShares: 1)
  let tick = Move(.stockTick, player: 1, seq: 0)
  let next = try host.commitOnHost(tick).get().0
  guest.receiveNetworkPacket(.init(roomID: config.roomID, kind: .commit,
   committed: .init(seq: 0, move: tick, stateHash: StateDigest.hash(next))), from: "host")
  XCTAssertTrue(guest.awaitingHost)
  guest.receiveNetworkPacket(.init(roomID: config.roomID, kind: .snapshot, snapshot: GameSnapshot(next)), from: "host")
  XCTAssertFalse(guest.awaitingHost)
  XCTAssertEqual(guest.game.players[1].cash, initial.players[1].cash)
 }
}
#endif
