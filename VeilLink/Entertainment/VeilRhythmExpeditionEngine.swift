import Foundation

/// E191 prototype: deterministic four-district rhythm exploration.
/// Pure Foundation; no microphone, player identity, BLE or app database access.
public enum VeilRhythmExpedition {
    public static let districtCount = 4
    public static let beatsPerDistrict = 16
    public static let maxHistory = 256

    public enum District: Int, Codable, CaseIterable, Sendable {
        case rainAlley, emptyStation, riverEcho, observatory
        public var title: String {
            switch self {
            case .rainAlley: return "雨巷初响"
            case .emptyStation: return "无人车站"
            case .riverEcho: return "河岸回声"
            case .observatory: return "穹顶演出"
            }
        }
    }

    public enum Phase: String, Codable, Sendable { case playing, cleared, failed }
    public enum Quality: String, Codable, Sendable { case perfect, good, miss }
    public enum Command: Codable, Equatable, Sendable {
        case tap(beat: Int, lane: Int, offset: Double)
        case travel
    }
    public enum Failure: Error, Equatable {
        case badBeat, badLane, badOffset, districtLocked, inactive, sessionTooLong
    }

    public struct Note: Codable, Equatable, Sendable {
        public let district: Int
        public let beat: Int
        public let lane: Int
        public let nominalTime: Double
    }
    public struct Event: Codable, Equatable, Sendable {
        public let command: Command
        public let district: Int
        public let quality: Quality?
        public let score: Int
        public let focus: Int
    }

    // Same seed and district always produce the same four-lane chart.
    public static func note(seed: UInt64, district: Int, beat: Int) -> Note? {
        guard (0..<districtCount).contains(district), (0..<beatsPerDistrict).contains(beat) else { return nil }
        var a = seed ^ UInt64(district + 1) &* 0x9e3779b97f4a7c15
        a ^= UInt64(beat + 7) &* 0xbf58476d1ce4e5b9
        a = (a ^ (a >> 30)) &* 0xbf58476d1ce4e5b9
        let lane = Int((a ^ (a >> 27)) % 4)
        return Note(district: district, beat: beat, lane: lane,
                    nominalTime: Double(beat) * (60.0 / (100.0 + Double(district) * 15.0)))
    }

    public struct Session: Codable, Sendable {
        public let seed: UInt64
        public private(set) var district = 0
        public private(set) var nextBeat = 0
        public private(set) var phase: Phase = .playing
        public private(set) var score = 0
        public private(set) var combo = 0
        public private(set) var bestCombo = 0
        public private(set) var focus = 100
        public private(set) var collectedFragments = 0
        public private(set) var history: [Event] = []
        public private(set) var totalActions = 0
        public init(seed: UInt64) { self.seed = seed }
        public var districtCompleted: Bool { nextBeat == beatsPerDistrict }
        public var expectedNote: Note? { VeilRhythmExpedition.note(seed: seed, district: district, beat: nextBeat) }
        public var progress: Double {
            Double(district * beatsPerDistrict + nextBeat) / Double(districtCount * beatsPerDistrict)
        }

        @discardableResult
        public mutating func perform(_ command: Command) throws -> Event {
            guard phase == .playing else { throw Failure.inactive }
            guard totalActions < 1024 else { throw Failure.sessionTooLong }
            var judgement: Quality?
            switch command {
            case let .tap(beat, lane, offset):
                guard !districtCompleted, beat == nextBeat else { throw Failure.badBeat }
                guard (0...3).contains(lane) else { throw Failure.badLane }
                guard offset.isFinite, abs(offset) <= 1 else { throw Failure.badOffset }
                let expected = VeilRhythmExpedition.note(seed: seed, district: district, beat: nextBeat)!
                if expected.lane == lane && abs(offset) <= 0.075 {
                    judgement = .perfect
                    combo += 1
                    score += 300 + min(combo, 30) * 2
                    focus = min(100, focus + 2)
                } else if expected.lane == lane && abs(offset) <= 0.18 {
                    judgement = .good
                    combo += 1
                    score += 100 + min(combo, 30)
                    focus = min(100, focus + 1)
                } else {
                    judgement = .miss
                    combo = 0
                    focus = max(0, focus - 12)
                }
                bestCombo = max(bestCombo, combo)
                nextBeat += 1
                if nextBeat == beatsPerDistrict { collectedFragments += 1 }
                if focus == 0 { phase = .failed }
                if district == districtCount - 1 && districtCompleted && phase != .failed { phase = .cleared }
            case .travel:
                guard districtCompleted, district < districtCount - 1 else { throw Failure.districtLocked }
                district += 1
                nextBeat = 0
                focus = min(100, focus + 10)
            }
            let event = Event(command: command, district: district,
                              quality: judgement, score: score, focus: focus)
            totalActions += 1
            if history.count == VeilRhythmExpedition.maxHistory { history.removeFirst() }
            history.append(event)
            return event
        }
    }

    public static func replay(seed: UInt64, commands: [Command]) throws -> Session {
        guard commands.count <= 1024 else { throw Failure.sessionTooLong }
        var session = Session(seed: seed)
        for command in commands { try session.perform(command) }
        return session
    }
}
