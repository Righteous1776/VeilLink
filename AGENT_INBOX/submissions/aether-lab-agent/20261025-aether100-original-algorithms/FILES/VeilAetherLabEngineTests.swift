import XCTest
@testable import VeilLink

final class VeilAetherLabEngineTests: XCTestCase {
    func testUniqueHundredFeaturesAndGroups() throws {
        let all=VeilAetherEngine.catalog
        XCTAssertEqual(all.count, 100)
        XCTAssertEqual(Set(all.map(\.number)).count,100)
        XCTAssertEqual(Set(all.map(\.domain)).count,10)
        XCTAssertEqual(all.first?.number,201)
        XCTAssertEqual(all.last?.number,300)
    }
    func testAllOneHundredExecutableAndDeterministic() throws {
        for feature in VeilAetherEngine.catalog {
            let first=try VeilAetherEngine.run(feature.number,json:VeilAetherEngine.exampleJSON)
            let second=try VeilAetherEngine.run(feature.number,json:VeilAetherEngine.exampleJSON)
            XCTAssertEqual(first,second,"feature \(feature.number) nondeterministic")
            XCTAssertFalse(first.output.isEmpty,"feature \(feature.number) empty")
        }
    }
    func testInputSizeAndMalformedData() throws {
        XCTAssertThrowsError(try VeilAetherEngine.run(201,json:"not JSON"))
        XCTAssertThrowsError(try VeilAetherEngine.run(201,json:"{\"foo\":\""+String(repeating:"a",count:32769)+"\"}"))
        XCTAssertThrowsError(try VeilAetherEngine.run(301,json:"{}"))
        XCTAssertThrowsError(try VeilAetherEngine.run(201,json:"[]"))
    }
    func testGraphAndShortestPaths() throws {
        let sample="{\"edges\":[[0,1],[1,2],[2,3],[3,4]]}"
        XCTAssertTrue(try VeilAetherEngine.run(202,json:sample).output.contains("12"))
        XCTAssertTrue(try VeilAetherEngine.run(203,json:sample).output.contains("4"))
        XCTAssertTrue(try VeilAetherEngine.run(206,json:sample).output.contains("1"))
    }
    func testSignalMedianAndMAD() throws {
        let s="{\"numbers\":[1,1,1,1,100]}"
        XCTAssertTrue(try VeilAetherEngine.run(212,json:s).output.contains("1.0000"))
        XCTAssertTrue(try VeilAetherEngine.run(216,json:s).output.contains("1"))
    }
    func testClockAndQuorum() throws {
        let s="{\"numbers\":[1,2,3,4,5,6],\"flags\":[true,true,false]}"
        XCTAssertTrue(try VeilAetherEngine.run(225,json:s).output.contains("满足"))
        XCTAssertTrue(try VeilAetherEngine.run(223,json:s).output.contains("A 先于 B"))
    }
    func testCRCAndPrivacy() throws {
        let s="{\"text\":\"123456789\"}"
        XCTAssertTrue(try VeilAetherEngine.run(237,json:s).output.lowercased().contains("cbf43926"))
    }
    func testAreaAndConvexHull() throws {
        let s="{\"points\":[[0,0],[4,0],[4,3],[0,3]]}"
        XCTAssertTrue(try VeilAetherEngine.run(271,json:s).output.contains("12.0000"))
        XCTAssertTrue(try VeilAetherEngine.run(273,json:s).output.contains("4"))
    }
    func testKnowledgeAndEditDistance() throws {
        let s="{\"strings\":[\"kitten\",\"sitting\"],\"text\":\"cat cat dog\"}"
        XCTAssertTrue(try VeilAetherEngine.run(264,json:s).output.contains("3"))
        XCTAssertTrue(try VeilAetherEngine.run(262,json:s).output.contains("2"))
    }
    func testGameAndReliableGate() throws {
        let s="{\"grid\":[[0,0],[0,0]],\"numbers\":[1,2,3,4]}"
        XCTAssertTrue(try VeilAetherEngine.run(251,json:s).output.contains("2"))
        XCTAssertTrue(try VeilAetherEngine.run(252,json:s).output.contains("2"))
        XCTAssertTrue(try VeilAetherEngine.run(281,json:s).output.contains("P95"))
    }
    func testEmptyDataDoesNotCrashAcrossAllFeatures() throws {
        for feature in VeilAetherEngine.catalog {
            let report=try VeilAetherEngine.run(feature.number,json:"{}")
            XCTAssertFalse(report.output.isEmpty,"failed \(feature.number)")
        }
    }
    func testExtremeNumericAndMalformedShapeSafety() throws {
        let cases = [
            "{\"numbers\":[1e100,-1e100,0,0],\"grid\":[[1,0],[]]}",
            "{\"numbers\":[-100000000,0,100000000],\"edges\":[[-1,3],[200,1],[3,3]]}",
            "{\"points\":[[100000,100000],[-100000,-100000]],\"text\":\"😀 é 漢字\"}",
            "{\"numbers\":[],\"strings\":[],\"edges\":[],\"grid\":[],\"flags\":[]}"
        ]
        for sample in cases {
            for feature in VeilAetherEngine.catalog {
                let report = try VeilAetherEngine.run(feature.number,json:sample)
                XCTAssertFalse(report.output.isEmpty,"\(feature.number) with input \(sample)")
            }
        }
    }
}
