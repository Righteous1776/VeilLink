import Foundation

private nonisolated(unsafe) var checked = 0
private func check(_ condition: Bool, _ message: String) {
    checked += 1
    precondition(condition, "TEST \(checked): \(message)")
}
private func fails(_ body: () throws -> Void) -> Bool {
    do { try body(); return false } catch { return true }
}

@main struct R10ArchiveThoughtTests {
    static func main() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("VeilEclipseR10-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let journal = root.appendingPathComponent("legacy-current.json")
        try Data("legacy-current-is-not-our-file".utf8).write(to: journal)
        let archive = VeilGomokuMatchArchive(directory: root.appendingPathComponent("History"))
        typealias M = VeilGomokuMatchArchive.Move
        let id = UUID().uuidString
        let m1 = [M(index: 112, stone: 1)]
        let m2 = m1 + [M(index: 113, stone: 2)]
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        let t1 = t0.addingTimeInterval(10)
        let t2 = t0.addingTimeInterval(20)
        check(try archive.page().totalFiles == 0, "Fresh store empty")
        check(try archive.save(sessionID: id, moves: [], difficulty: "均衡", humanStone: 1, status: .playing) == nil, "Empty games not created")
        check(try archive.page().totalFiles == 0, "Still no empty archive")
        let first = try archive.save(sessionID: id, moves: m1, difficulty: "均衡", humanStone: 1, status: .playing, now: t0)!
        check(first.moves.count == 1 && first.startedAt == t0 && first.completedAt == nil, "First committed move stored")
        check(try archive.read(sessionID: id)?.moves == m1, "First move reload")
        let second = try archive.save(sessionID: id, moves: m2, difficulty: "传奇", humanStone: 1, status: .playing, now: t1)!
        check(second.moves.count == 2 && second.startedAt == t0 && second.difficulty == "均衡", "Append does not reset metadata")
        check(try archive.read(sessionID: id)?.isReplayable == true, "Recorded actions can replay")
        check(fails { try archive.save(sessionID: id, moves: [M(index: 5, stone: 1)], difficulty: "均衡", humanStone: 1, status: .playing) }, "Past cannot be rewritten")
        check(fails { try archive.save(sessionID: id, moves: m1, difficulty: "均衡", humanStone: 1, status: .playing) }, "Past cannot be truncated")
        check(fails { try archive.save(sessionID: id, moves: [M(index: 225, stone: 1)], difficulty: "均衡", humanStone: 1, status: .playing) }, "Out of range invalid")
        check(fails { try archive.save(sessionID: UUID().uuidString, moves: [M(index: 4, stone: 2)], difficulty: "均衡", humanStone: 1, status: .playing) }, "White cannot start")
        check(fails { try archive.save(sessionID: UUID().uuidString, moves: [M(index: 5, stone: 1), M(index: 5, stone: 2)], difficulty: "均衡", humanStone: 1, status: .playing) }, "Duplicate cell invalid")
        check(fails { try archive.save(sessionID: "../escape", moves: m2, difficulty: "均衡", humanStone: 1, status: .playing) }, "Traversal invalid")
        let final = try archive.save(sessionID: id, moves: m2, difficulty: "均衡", humanStone: 1, status: .interrupted, now: t2)!
        check(final.completedAt == t2 && final.status == .interrupted, "Interrupted games retained")
        check(try archive.save(sessionID: id, moves: m2, difficulty: "均衡", humanStone: 1, status: .interrupted)!.updatedAt == t2, "Finalization idempotent")
        check(fails { try archive.save(sessionID: id, moves: m2 + [M(index: 114, stone: 1)], difficulty: "均衡", humanStone: 1, status: .playing) }, "Final entry immutable")
        check(try Data(contentsOf: journal) == Data("legacy-current-is-not-our-file".utf8), "Legacy current match untouched")

        // Legitimately won game; black plays five stones across the first row.
        let winID = UUID().uuidString
        let winning = [M(index: 0,stone:1), M(index:15,stone:2), M(index:1,stone:1), M(index:16,stone:2),
                       M(index:2,stone:1), M(index:17,stone:2), M(index:3,stone:1), M(index:18,stone:2), M(index:4,stone:1)]
        try archive.save(sessionID: winID, moves: winning, difficulty: "宗师", humanStone: 1, status: .playing)
        let won = try archive.save(sessionID: winID, moves: winning, difficulty: "宗师", humanStone: 1, status: .humanWon)!
        check(won.status == .humanWon && won.isReplayable, "Terminal win verified and saved")
        check(fails { try archive.save(sessionID: UUID().uuidString, moves: winning, difficulty: "宗师", humanStone: 1, status: .draw) }, "Win cannot be labeled draw")
        check(fails { try archive.save(sessionID: UUID().uuidString, moves: winning, difficulty: "宗师", humanStone: 2, status: .humanWon) }, "Winner cannot be mislabeled")
        check(fails { try archive.save(sessionID: UUID().uuidString, moves: winning, difficulty: "宗师", humanStone: 1, status: .interrupted) }, "Won game cannot be aborted")
        check(fails { try archive.save(sessionID: UUID().uuidString, moves: winning + [M(index: 19, stone: 2)], difficulty: "宗师", humanStone: 1, status: .playing) }, "No moves after five")

        for i in 0..<143 {
            let unique = UUID().uuidString
            try archive.save(sessionID: unique, moves: m2, difficulty: "测试\(i)", humanStone: 1, status: .interrupted)
        }
        let pg1 = try archive.page(offset: 0, limit: 30)
        check(pg1.matches.count == 30 && pg1.totalFiles == 145 && pg1.nextOffset == 30, "Paged 145 matches")
        let pg2 = try archive.page(offset: 30, limit: 100)
        check(pg2.matches.count == 100 && pg2.nextOffset == 130, "Second page 100 and next cursor")
        let pg3 = try archive.page(offset: 130, limit: 100)
        check(pg3.matches.count == 15 && pg3.nextOffset == nil, "Last page completes all")
        let ids = (pg1.matches + pg2.matches + pg3.matches).map(\.id)
        check(Set(ids).count == 145, "No match overwritten when scrolling")
        let poisoned = root.appendingPathComponent("History").appendingPathComponent(UUID().uuidString + ".json")
        try Data("malformed-not-json".utf8).write(to: poisoned)
        let failedPage = try archive.page(offset: 0, limit: 100)
        check(failedPage.totalFiles == 146, "Corrupt record is counted, never discarded")
        check(FileManager.default.fileExists(atPath: poisoned.path), "Corrupt archive retained")
        let later = try archive.page(offset: 100, limit: 100)
        check(failedPage.invalidFiles + later.invalidFiles == 1, "Damaged file is reported during pagination")

        let a = VeilEclipseThoughtPattern.frame(frame: 30, count: 140)
        check(a.count == 140 && a == VeilEclipseThoughtPattern.frame(frame: 30, count: 140), "Deterministic abstract animation")
        check(a != VeilEclipseThoughtPattern.frame(frame: 31, count: 140), "Animation evolves with clock")
        check(a.allSatisfy { (0...1).contains($0.x) && (0...1).contains($0.y) && (0..<4).contains($0.tone) }, "No coordinates outside canvas")
        check(VeilEclipseThoughtPattern.density(elapsedSeconds: 0, lowPower: false) < VeilEclipseThoughtPattern.density(elapsedSeconds: 10, lowPower: false), "Visual buildup tracks elapsed time only")
        check(VeilEclipseThoughtPattern.density(elapsedSeconds: 30, lowPower: true) <= 80, "Low power path bounded")
        check(VeilEclipseThoughtPattern.frame(frame: -5, count: 10).isEmpty, "Invalid frame safe")
        check(VeilEclipseThoughtPattern.frame(frame: 100, count: -1).isEmpty, "Invalid count safe")
        print("PASS: \(checked) R10 archive + decorative-board-pattern assertions")
    }
}
