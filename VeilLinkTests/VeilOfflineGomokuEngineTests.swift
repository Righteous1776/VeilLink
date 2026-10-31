import Foundation
import JavaScriptCore
import XCTest
@testable import VeilLink

final class VeilOfflineGomokuEngineTests: XCTestCase {
    func testOfflineExternalEngineCanReturnLegalReply() async {
        var state = GomokuState()
        XCTAssertTrue(state.apply(index: 112, actor: .host))
        let move = await VeilOfflineGomokuEngine.shared.chooseMove(
            in: state, for: .guest, timeLimitMilliseconds: 250, maxDepth: 3
        )
        XCTAssertNotNil(move, "Bundled engine must load without network access")
        if let move {
            XCTAssertEqual(state.value(at: move.index), 0)
            XCTAssertTrue(state.apply(index: move.index, actor: .guest))
        }
    }

    func testExternalEngineBlocksOpponentImmediateWin() async {
        var state = GomokuState()
        for (turn, index) in [108, 0, 109, 1, 111, 2, 112].enumerated() {
            XCTAssertTrue(state.apply(
                index: index, actor: turn.isMultiple(of: 2) ? .host : .guest
            ))
        }
        let move = await VeilOfflineGomokuEngine.shared.chooseMove(
            in: state, for: .guest, timeLimitMilliseconds: 250, maxDepth: 3
        )
        XCTAssertEqual(move?.index, 110)
    }

    func testBundledEngineUsesFreestyleNotRenjuRestrictions() {
        guard let url = Bundle.main.url(
            forResource: "engine", withExtension: "js", subdirectory: "GomokuEngineV2"
        ), let source = try? String(contentsOf: url, encoding: .utf8),
           let context = JSContext() else {
            XCTFail("Missing bundled JS engine")
            return
        }
        context.evaluateScript(source)
        XCTAssertNil(context.exception)
        guard let e = context.objectForKeyedSubscript("GomokuEngine"),
              let board = e.forProperty("Board")?.construct(withArguments: []) else {
            XCTFail("No engine Board constructor")
            return
        }
        for col in [3, 4, 5, 6, 8] {
            board.invokeMethod("play", withArguments: [7, col, 1])
        }
        let forbidden = e.invokeMethod("isForbidden", withArguments: [board, 7, 7])
        XCTAssertEqual(forbidden?.toBool(), false, "Overline legal in VeilLink freestyle Gomoku")
    }
}
