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

enum VeilEmotionContext: String, CaseIterable, Identifiable, Sendable {
    case morning
    case midday
    case night
    case alone
    case commute
    case workBreak
    case afterCompletion
    case waiting
    case rainyDay
    case specialDay

    var id: String { rawValue }

    var title: String {
        switch self {
        case .morning: return "晨间"
        case .midday: return "午间"
        case .night: return "夜间"
        case .alone: return "独处"
        case .commute: return "通勤"
        case .workBreak: return "工作间隙"
        case .afterCompletion: return "完成之后"
        case .waiting: return "等待中"
        case .rainyDay: return "雨天"
        case .specialDay: return "特别日子"
        }
    }
}

struct VeilEmotionRitual: Identifiable, Equatable, Sendable {
    let id: String
    let tone: VeilEmotionTone
    let kind: VeilEmotionRitualKind
    let context: VeilEmotionContext
    let title: String
    let prompt: String
    let seconds: Int
    let symbol: String
}

enum VeilEmotionGardenEngine {
    /// 1,000 executable micro-rituals: 10 tones × 10 safe ritual forms × 10 contexts.
    /// They are local prompts, not diagnosis, therapy, or crisis care.
    static let rituals: [VeilEmotionRitual] = {
        var result: [VeilEmotionRitual] = []
        result.reserveCapacity(1_000)
        for (toneIndex, tone) in VeilEmotionTone.allCases.enumerated() {
            for (kindIndex, kind) in VeilEmotionRitualKind.allCases.enumerated() {
                for (contextIndex, context) in VeilEmotionContext.allCases.enumerated() {
                    let number = toneIndex * 100 + kindIndex * 10 + contextIndex + 1
                    result.append(VeilEmotionRitual(
                        id: String(format: "EV-%04d", number),
                        tone: tone,
                        kind: kind,
                        context: context,
                        title: "\(tone.title) · \(context.title) · \(kind.title)",
                        prompt: prompt(tone: tone, kind: kind, context: context),
                        seconds: duration(kind, context: context),
                        symbol: symbol(kind)
                    ))
                }
            }
        }
        return result
    }()

    static func rituals(for tone: VeilEmotionTone) -> [VeilEmotionRitual] {
        rituals.filter { $0.tone == tone }
    }

    static func rituals(for tone: VeilEmotionTone, context: VeilEmotionContext) -> [VeilEmotionRitual] {
        rituals.filter { $0.tone == tone && $0.context == context }
    }

    static func ritual(id: String) -> VeilEmotionRitual? {
        rituals.first { $0.id == id }
    }

    static func dailyPath(
        for tone: VeilEmotionTone,
        context: VeilEmotionContext,
        date: Date,
        calendar: Calendar = .current
    ) -> [VeilEmotionRitual] {
        let source = rituals(for: tone, context: context)
        guard !source.isEmpty else { return [] }
        let day = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        let seed = tone.rawValue + context.rawValue
        let start = (day + seed.unicodeScalars.reduce(0) { $0 + Int($1.value) }) % source.count
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

    private static func duration(_ kind: VeilEmotionRitualKind, context: VeilEmotionContext) -> Int {
        let base: Int
        switch kind {
        case .breath: base = 60
        case .notice, .name, .anchor: base = 45
        case .kindness, .gratitude, .smallWin, .connection, .reset, .play: base = 90
        }
        return context == .commute || context == .waiting ? max(30, base - 15) : base
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

    private static func prompt(tone: VeilEmotionTone, kind: VeilEmotionRitualKind, context: VeilEmotionContext) -> String {
        let subjects: [VeilEmotionTone: String] = [
            .calm: "此刻的平静", .low: "这份低落", .tense: "这股紧绷", .tired: "这份疲惫", .lonely: "这份孤单",
            .joyful: "这份愉快", .proud: "这份成就感", .uncertain: "这份不确定", .focused: "这份专注", .playful: "这点玩心"
        ]
        let subject = subjects[tone] ?? "此刻的感受"
        let opening: String
        switch context {
        case .morning: opening = "在今天刚开始的时候，"
        case .midday: opening = "在一天走到中段的时候，"
        case .night: opening = "在准备结束今天之前，"
        case .alone: opening = "在只属于你的这段时间里，"
        case .commute: opening = "在安全、不影响行程的前提下，"
        case .workBreak: opening = "把工作暂放片刻，"
        case .afterCompletion: opening = "完成一件事之后，"
        case .waiting: opening = "利用眼前这小段等待，"
        case .rainyDay: opening = "让雨声成为背景，"
        case .specialDay: opening = "给这个特别的日子留一点位置，"
        }
        switch kind {
        case .notice: return "\(opening)不评价地观察 \(subject)：身体、呼吸和念头各是什么样？"
        case .breath: return "\(opening)带着 \(subject)吸气 3 拍、停留 1 拍、呼气 4 拍；按舒服的速度做 6 轮。"
        case .name: return "\(opening)用三个词给 \(subject)命名；不需要解释，也不需要修正。"
        case .kindness: return "\(opening)想想朋友若正经历 \(subject)，你会说哪句温和的话；也把它留给自己。"
        case .anchor: return "\(opening)带着 \(subject)找出能看见的 3 个细节、能触到的 2 个触感、能听到的 1 个声音。"
        case .gratitude: return "\(opening)写下一个不必宏大、却让 \(subject)有了细微变化的瞬间。"
        case .smallWin: return "\(opening)记录一个在 \(subject)中仍然完成的小动作；再小也算。"
        case .connection: return "\(opening)想一个能接住 \(subject)的人或地方；合适时发一条无需回复的轻消息。"
        case .reset: return "\(opening)为带着 \(subject)的下一步选一个两分钟动作：喝水、洗脸、站起来或整理一角。"
        case .play: return "\(opening)允许 \(subject)和一点玩心同时存在：涂鸦、随手拍、哼一句旋律或看一眼天空。"
        }
    }
}
