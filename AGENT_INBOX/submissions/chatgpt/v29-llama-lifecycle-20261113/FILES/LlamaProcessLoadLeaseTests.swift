import XCTest
@testable import VeilLink

@MainActor
final class LlamaProcessLoadLeaseTests: XCTestCase {
    func testLeaseStartsFreeAndCanBeReacquiredAfterRelease() async {
        let lease = LlamaProcessLoadLease()
        XCTAssertFalse(lease.hasOwner)
        await lease.acquire()
        XCTAssertTrue(lease.hasOwner)
        lease.release()
        XCTAssertFalse(lease.hasOwner)
        await lease.acquire()
        XCTAssertTrue(lease.hasOwner)
        lease.release()
    }

    func testSecondRuntimeBlocksUntilFirstFullyReleases() async {
        let lease = LlamaProcessLoadLease()
        await lease.acquire()
        let second = Task { @MainActor in
            await lease.acquire()
            return lease.hasOwner
        }
        for _ in 0..<200 {
            if lease.waitingCount == 1 { break }
            await Task.yield()
        }
        XCTAssertEqual(lease.waitingCount, 1)
        XCTAssertTrue(lease.hasOwner)
        lease.release()
        let received = await second.value
        XCTAssertTrue(received)
        lease.release()
        XCTAssertFalse(lease.hasOwner)
    }

    func testCancelledWaiterStillMustReleaseLeaseWhenResumed() async {
        let lease = LlamaProcessLoadLease()
        await lease.acquire()
        let second = Task { @MainActor in
            await lease.acquire()
            // Cancellation after enqueue does not remove the continuation.
            // The runtime rechecks its epoch then releases this lease.
            let wasCancelled = Task.isCancelled
            lease.release()
            return wasCancelled
        }
        for _ in 0..<200 {
            if lease.waitingCount == 1 { break }
            await Task.yield()
        }
        XCTAssertEqual(lease.waitingCount, 1)
        second.cancel()
        lease.release()
        let wasCancelled = await second.value
        XCTAssertTrue(wasCancelled)
        XCTAssertFalse(lease.hasOwner)
    }
}
