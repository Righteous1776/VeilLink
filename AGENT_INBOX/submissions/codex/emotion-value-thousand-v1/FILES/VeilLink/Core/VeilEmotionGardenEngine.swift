import Foundation

enum VeilEmotionTone: String, CaseIterable, Identifiable, Sendable {
    case calm
    case low
    case tense
    case tired
    case lonely
    case joyful
    case proud
    case uncertain
    case focused
    case playful

    var id: String { rawValue }

    var title: String {
        switch self {
        case .calm: return "平静"
        case .low: return "低落"
        case .tense: return "紧绷"
        case .tired: return "疲惫"
        case .lonely: return "孤单"
        case .joyful: return "愉快"
        case .proud: return "有成就感"
        case .uncertain: return "不确定"
        case .focused: return "想专注"
        case .playful: return "想玩一会"
        }
    }
}

enum VeilEmotionRitualKind: String, CaseIterable, Identifiable, Sendable {
    case notice
    case breath
    case name
    case kindness
    case anchor
    case gratitude
    case smallWin
    case connection
    case reset
    case play

    var id: String { rawValue }

    var title: String {
        switch self {
        case .notice: return "一分钟觉察"
        case .breath: return "呼吸节拍"
        case .name: return "给感受命名"
        case .kindness: return "给自己一句话"
        case .anchor: return "感官锚点"
        case .gratitude: return "微小感谢"
        case .smallWin: return "收集小胜利"
        case .connection: return "轻连接"
        case .reset: return "温和重启"
        case .play: return "一点玩心"
        }
    }
}

struct VeilEmotionRitual: Identifiable, Equatable, Sendable {
    let id: String
    let tone: VeilEmotionTone
    let kind: VeilEmotionRitualKind
    let title: String
    let prompt: String
    let seconds: Int
    let symbol: String
}

enum VeilEmotionGardenEngine {
    /// The first 100 executable micro-rituals are generated from 10 tones × 10 safe ritual forms.
    /// They are local prompts, not diagnosis, therapy, or crisis care.
    static let rituals: [VeilEmotionRitual] = VeilEmotionTone.allCases.flatMap { tone in
        VeilEmotionRitualKind.allCases.map { kind in
            VeilEmotionRitual(
                id: "EVG-\(tone.rawValue)-\(kind.rawValue)",
                tone: tone,
                kind: kind,
                title: "\(tone.title) · \(kind.title)",
                prompt: prompt(tone: tone, kind: kind),
                seconds: duration(kind),
                symbol: symbol(kind)
            )
        }
    }

    static func rituals(for tone: VeilEmotionTone) -> [VeilEmotionRitual] {
        rituals.filter { $0.tone == tone }
    }

    static func dailyPath(for tone: VeilEmotionTone, date: Date, calendar: Calendar = .current) -> [VeilEmotionRitual] {
        let source = rituals(for: tone)
        guard !source.isEmpty else { return [] }
        let day = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        let start = (day + tone.rawValue.unicodeScalars.reduce(0) { $0 + Int($1.value) }) % source.count
        return (0..<min(3, source.count)).map { source[(start + $0) % source.count] }
    }

    static func supportiveNote(for tone: VeilEmotionTone) -> String {
        switch tone {
        case .calm: return "把这份平静留给接下来的十分钟。"
        case .low: return "低落不需要立刻被解决；先给自己一点空间。"
        case .tense: return "先放慢一点点，就已经是在照顾自己。"
        case .tired: return "疲惫不是失败，它在提醒你需要补给。"
        case .lonely: return "想被理解是很自然的需要；可以从一条轻消息开始。"
        case .joyful: return "值得把这份愉快认真记住。"
        case .proud: return "你完成的部分，确实是你做成的。"
        case .uncertain: return "不知道下一步也没关系，只选一个最小动作就好。"
        case .focused: return "把注意力交给眼前这一小段，而不是全部。"
        case .playful: return "一点无目的的玩心，也可以是能量。"
        }
    }

    private static func duration(_ kind: VeilEmotionRitualKind) -> Int {
        switch kind {
        case .breath: return 60
        case .notice, .name, .anchor: return 45
        case .kindness, .gratitude, .smallWin, .connection, .reset, .play: return 90
        }
    }

    private static func symbol(_ kind: VeilEmotionRitualKind) -> String {
        switch kind {
        case .notice: return "eye.fill"
        case .breath: return "wind"
        case .name: return "text.bubble.fill"
        case .kindness: return "heart.fill"
        case .anchor: return "hand.raised.fill"
        case .gratitude: return "sparkles"
        case .smallWin: return "checkmark.seal.fill"
        case .connection: return "person.2.fill"
        case .reset: return "arrow.clockwise"
        case .play: return "face.smiling.fill"
        }
    }

    private static func prompt(tone: VeilEmotionTone, kind: VeilEmotionRitualKind) -> String {
        let context: [VeilEmotionTone: String] = [
            .calm: "此刻的平静", .low: "这份低落", .tense: "这股紧绷", .tired: "这份疲惫", .lonely: "这份孤单",
            .joyful: "这份愉快", .proud: "这份成就感", .uncertain: "这份不确定", .focused: "这份专注", .playful: "这点玩心"
        ]
        let subject = context[tone] ?? "此刻的感受"
        switch kind {
        case .notice: return "不评价地观察 \(subject)：身体、呼吸和念头各是什么样？"
        case .breath: return "吸气 3 拍、停留 1 拍、呼气 4 拍。按舒服的速度做 6 轮。"
        case .name: return "用三个词给 \(subject) 命名；不需要解释，也不需要修正。"
        case .kindness: return "如果朋友正经历同样的事，你会对他/她说哪一句温和的话？也把它留给自己。"
        case .anchor: return "找出你现在能看见的 3 个细节、能触到的 2 个触感、能听到的 1 个声音。"
        case .gratitude: return "写下一个不必宏大、但今天确实让你感到一点点好的瞬间。"
        case .smallWin: return "记录一个已经完成的小动作。再小也算，它说明你在前进。"
        case .connection: return "想一个让你感觉安全的人或地方；如果合适，发一条无需回复的轻消息。"
        case .reset: return "为下一步选一个两分钟以内的动作：喝水、洗脸、站起来，或清空桌面一角。"
        case .play: return "给自己 90 秒做一件没有产出的事：涂鸦、随手拍、哼一句旋律，或看一眼天空。"
        }
    }
}
