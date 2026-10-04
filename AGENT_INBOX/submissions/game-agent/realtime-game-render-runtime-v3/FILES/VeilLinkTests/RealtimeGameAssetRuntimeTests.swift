import XCTest
import CoreGraphics
@testable import VeilLink

final class RealtimeGameAssetRuntimeTests: XCTestCase {
    func testStandardProfile() {
        let profile =
            RealtimeGameRenderProfile
                .resolve(
                    sceneSize:
                        CGSize(
                            width: 390,
                            height: 844
                        ),
                    reduceMotion: false
                )

        XCTAssertEqual(
            profile.lod,
            .standard
        )
        XCTAssertEqual(
            profile.particleMultiplier,
            1.0
        )
        XCTAssertEqual(
            profile.detailMultiplier,
            1.0
        )
    }

    func testCinematicProfileForLargeCanvas() {
        let profile =
            RealtimeGameRenderProfile
                .resolve(
                    sceneSize:
                        CGSize(
                            width: 1_024,
                            height: 1_366
                        ),
                    reduceMotion: false
                )

        XCTAssertEqual(
            profile.lod,
            .cinematic
        )
        XCTAssertGreaterThan(
            profile.particleMultiplier,
            1.0
        )
        XCTAssertGreaterThan(
            profile.detailMultiplier,
            1.0
        )
    }

    func testReduceMotionWinsOverCanvasSize() {
        let profile =
            RealtimeGameRenderProfile
                .resolve(
                    sceneSize:
                        CGSize(
                            width: 1_024,
                            height: 1_366
                        ),
                    reduceMotion: true
                )

        XCTAssertEqual(
            profile.lod,
            .motionReduced
        )
        XCTAssertLessThan(
            profile.particleMultiplier,
            1.0
        )
        XCTAssertLessThan(
            profile.noiseMultiplier,
            1.0
        )
    }

    func testAssetAliasesRemainUnique() {
        let aliases =
            RealtimeGameAssetID
                .allCases
                .map(
                    \.imageAlias
                )

        XCTAssertEqual(
            aliases.count,
            Set(aliases).count
        )
    }

    func testModelResourceNamesRemainUnique() {
        let resources =
            RealtimeGameAssetID
                .allCases
                .map(
                    \.modelResource
                )

        XCTAssertEqual(
            resources.count,
            Set(resources).count
        )
    }
}
