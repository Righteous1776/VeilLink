import Foundation

/// E192 · Railway Station Chronicle: twenty scripted days, four fictional eras.
/// Purely local narrative/management rules; does not read real transit data.
public enum VeilStationChronicle {
    public static let daysPerEra = 5
    public static let eraCount = 4
    public static let totalDays = daysPerEra * eraCount

    public enum Era: Int, Codable, CaseIterable, Sendable {
        case steam, electrification, renovation, future
        public var name: String {
            switch self {
            case .steam: return "蒸汽启程"
            case .electrification: return "电光换乘"
            case .renovation: return "旧站新生"
            case .future: return "星轨终章"
            }
        }
        public var narration: String {
            switch self {
            case .steam: return "雾散后的第一声汽笛，叫醒一座尚未命名的城市。"
            case .electrification: return "电车取代了汽笛，站台的约定却没有变。"
            case .renovation: return "旧站即将拆除，旅客递来一本泛黄的留言簿。"
            case .future: return "新列车抵达时，时间和故事终于在同一条线上相遇。"
            }
        }
    }
    public enum Project: String, Codable, CaseIterable, Sendable {
        case restore, archive, outreach, platform
        public var price: Int {
            switch self {
            case .restore: return 40
            case .archive, .outreach: return 25
            case .platform: return 80
            }
        }
    }
    public enum Command: Codable, Equatable, Sendable {
        case undertake(Project)
        case dispatch
        case closeDay
    }
    public enum Phase: String, Codable, Sendable { case running, completed, bankrupt, abandoned }
    public enum Failure: Error, Equatable {
        case inactive, alreadyPlanned, insufficientFunds, alreadyDispatched,
             dispatchRequired, duplicateClose, sessionTooLong, malformedSave
    }
    public struct Event: Codable, Equatable, Sendable {
        public let day: Int
        public let command: Command
        public let trust: Int
        public let funds: Int
        public let condition: Int
        public let served: Int
    }
    public struct Bulletin: Equatable, Sendable {
        public let day: Int
        public let era: Era
        public let visitors: Int
        public let speaker: String
        public let message: String
    }
    public struct Game: Codable, Sendable {
        public let seed: UInt64
        public private(set) var day = 0
        public private(set) var trust = 60
        public private(set) var funds = 240
        public private(set) var condition = 78
        public private(set) var capacity = 60
        public private(set) var historyPoints = 0
        public private(set) var totalServed = 0
        public private(set) var projectThisDay: Project? = nil
        public private(set) var dispatchedThisDay = false
        public private(set) var phase: Phase = .running
        public private(set) var events: [Event] = []
        public private(set) var commands: [Command] = []
        public init(seed: UInt64) { self.seed = seed }
        public var currentEra: Era { Era(rawValue: min(day / daysPerEra, 3))! }
        public var currentDay: Int { min(day + 1, totalDays) }
        public var progress: Double { Double(day) / Double(totalDays) }
        public var epilogue: String {
            guard phase == .completed else { return "列车仍在运行。" }
            return historyPoints >= 4 && trust >= 65 ?
                "旧站的故事被保存下来，下一代旅人仍能听见它的钟声。" :
                "城市继续向前，未收集的记忆仍留在旧站的窗边。"
        }
        public var bulletin: Bulletin {
            let names = ["站长澄川", "修复师铃野", "记录员遥", "旅客南星"]
            let messages = VeilStationChronicle.dayStories
            return Bulletin(day: currentDay, era: currentEra, visitors: VeilStationChronicle.demand(seed:seed, day:day),
                            speaker: names[currentEra.rawValue], message: messages[min(day, VeilStationChronicle.totalDays - 1)])
        }
        @discardableResult
        public mutating func apply(_ command: Command) throws -> Event {
            guard phase == .running else { throw Failure.inactive }
            guard commands.count < 100 else { throw Failure.sessionTooLong }
            var next = self // transactional: failed operations never modify state.
            switch command {
            case .undertake(let project):
                guard next.projectThisDay == nil else { throw Failure.alreadyPlanned }
                guard next.funds >= project.price else { throw Failure.insufficientFunds }
                next.funds -= project.price
                next.projectThisDay = project
                switch project {
                case .restore: next.condition = min(100, next.condition + 18)
                case .archive: next.historyPoints = min(20, next.historyPoints + 1); next.trust = min(100, next.trust + 3)
                case .outreach: next.trust = min(100, next.trust + 9)
                case .platform: next.capacity = min(140, next.capacity + 20)
                }
            case .dispatch:
                guard !next.dispatchedThisDay else { throw Failure.alreadyDispatched }
                next.dispatchedThisDay = true
                let served = min(next.capacity, next.bulletin.visitors)
                next.totalServed += served
                next.funds = min(100_000, next.funds + served * 3)
                let demand = next.bulletin.visitors
                next.trust = max(0, min(100, next.trust + (served * 10 >= demand * 7 ? 2 : -5)))
                next.condition = max(0, next.condition - (3 + next.currentEra.rawValue))
                if next.condition < 10 || next.trust == 0 { next.phase = .abandoned }
            case .closeDay:
                guard next.dispatchedThisDay else { throw Failure.dispatchRequired }
                next.day += 1
                next.projectThisDay = nil
                next.dispatchedThisDay = false
                if next.day == VeilStationChronicle.totalDays { next.phase = .completed }
            }
            let served = next.totalServed - totalServed
            let event = Event(day: day, command: command, trust: next.trust,
                              funds: next.funds, condition: next.condition, served: served)
            next.commands.append(command)
            if next.events.count == 256 { next.events.removeFirst() }
            next.events.append(event)
            self = next
            return event
        }
        public func exportReplay() throws -> Data {
            let record = Replay(version: 1, seed: seed, commands: commands)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            return try encoder.encode(record)
        }
    }
    public struct Replay: Codable, Sendable {
        public let version: Int
        public let seed: UInt64
        public let commands: [Command]
    }
    public static let dayStories: [String] = [
        "第一班试运行，煤烟与晨雾同时升起。旅客在手写时刻表前排成了队。",
        "一位少女把遗失的怀表交给站长，问列车能不能带走想念。",
        "暴雨浸湿木制站台，修复队决定先保住车票档案室。",
        "小提琴家在候车厅演奏，孩子们终于听见远方城市的声音。",
        "老站长留下第一本行车日志，封面写着：请把每一次抵达都记下来。",
        "电车架线架起时，旧汽笛被郑重挂进车站纪念角。",
        "钟表匠重新校准站台时钟，时间第一次变得安静而准确。",
        "城市举办灯火夜行节，停电中的旅客帮助点亮一盏又一盏灯。",
        "年轻维修师发现老日志夹着一张未寄出的家书。",
        "第一列夜间电车准点进站，昔日怀表的主人归来了。",
        "旧站修复公告贴出，人们对拆迁与保存提出不同意见。",
        "记录员发起口述历史采访，售票员讲起四十年前的暴雪。",
        "绘图师为旧建筑制作测绘图，墙面露出藏在灰尘后的壁画。",
        "一班因道路修缮改道的列车载来寻找祖父故事的年轻人。",
        "投票结束，人们决定让旧站钟楼与新线路共同存在。",
        "未来轨道铺设完毕，新旧时刻表第一次并排显示。",
        "数字档案室上线，老站长的笔记成为第一个可公开阅读的故事。",
        "无人驾驶测试列车缓缓驶入，但站台仍保留人工欢迎广播。",
        "车站举办跨时代照片展，曾经离别的人们在同一张合影里重逢。",
        "最后一声钟响传过河岸，乘客们把下一百年的第一张车票交给孩子。"
    ]
    public static func demand(seed: UInt64, day: Int) -> Int {
        guard (0..<totalDays).contains(day) else { return 0 }
        var v = seed ^ (UInt64(day + 1) &* 0x9e3779b97f4a7c15)
        v = (v ^ (v >> 30)) &* 0xbf58476d1ce4e5b9
        v = (v ^ (v >> 27)) &* 0x94d049bb133111eb
        v ^= v >> 31
        return 30 + Int(v % 61)
    }
    public static func replay(seed: UInt64, commands: [Command]) throws -> Game {
        guard commands.count <= 100 else { throw Failure.sessionTooLong }
        var game = Game(seed: seed)
        for command in commands { try game.apply(command) }
        return game
    }
    public static func importReplay(_ data: Data) throws -> Game {
        guard data.count <= 32_768 else { throw Failure.malformedSave }
        let record: Replay
        do { record = try JSONDecoder().decode(Replay.self,from:data) }
        catch { throw Failure.malformedSave }
        guard record.version == 1, record.commands.count <= 100 else { throw Failure.malformedSave }
        do { return try replay(seed: record.seed, commands: record.commands) }
        catch { throw Failure.malformedSave }
    }
}
