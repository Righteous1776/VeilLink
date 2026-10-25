import XCTest
@testable import VeilLink

final class VeilEntertainmentFeatureGateTests: XCTestCase {
    typealias Gate = VeilEntertainmentFeatureGate

    func testAllTwoHundredCanonicalIdentifiers() {
        let ids = (1...200).compactMap { Gate.id(for: $0) }
        XCTAssertEqual(ids.count, 200)
        XCTAssertEqual(Set(ids).count, 200)
        XCTAssertEqual(ids.first, "E01")
        XCTAssertEqual(ids[89], "E90")
        XCTAssertEqual(ids[90], "E091")
        XCTAssertEqual(ids.last, "E200")
    }
    func testInvalidIdsRejected() {
        for id in ["E0", "E1", "E001", "E090", "E201", "E-1", "", "Z191"] {
            XCTAssertNil(Gate.number(for: id))
        }
    }
    func testCandidateSetExactlyEight() {
        let candidates = (1...200).compactMap { Gate.id(for: $0) }.filter { Gate.state(for: $0) == .candidateCore }
        XCTAssertEqual(candidates.count, 8)
        XCTAssertTrue(candidates.contains("E191"))
        XCTAssertEqual(Gate.state(for: "E200"), .designed)
    }
    func testSafeByDefault() {
        for i in 1...200 {
            XCTAssertFalse(Gate.canPresent(Gate.id(for: i)!))
        }
    }
    func testPartialEvidenceCannotEnable() {
        let e = Gate.Evidence(productCompiled: true, incidentP0Cleared: true,
                              ios15DevicePassed: false, userOptedIn: true)
        XCTAssertFalse(Gate.canPresent("E191", evidence: e))
    }
    func testDesignedFeatureCannotEnableWithAllProofs() {
        let e = Gate.Evidence(productCompiled: true, incidentP0Cleared: true,
                              ios15DevicePassed: true, userOptedIn: true)
        XCTAssertFalse(Gate.canPresent("E200", evidence: e))
        XCTAssertTrue(Gate.canPresent("E191", evidence: e))
    }
}
