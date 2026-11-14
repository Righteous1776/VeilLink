import Foundation

enum VeilProductivityError: Error, Equatable, LocalizedError, Sendable {
    case templateTooLarge
    case malformedPlaceholder
    case missingVariables([String])
    case diffTooLarge
    case invalidTimeZone(String)
    case noParticipants
    case tooManyParticipants
    case invalidParticipantHours(String)
    case invalidImportLimit

    var errorDescription: String? {
        switch self {
        case .templateTooLarge: return "内容过长，请缩短后重试"
        case .malformedPlaceholder: return "模板占位符格式不完整"
        case let .missingVariables(names): return "仍缺少：\(names.joined(separator: "、"))"
        case .diffTooLarge: return "文本差异分析最多支持每侧 400 行、64 KB"
        case let .invalidTimeZone(identifier): return "未知时区：\(identifier)"
        case .noParticipants: return "至少需要一个协作时区"
        case .tooManyParticipants: return "一次最多规划 24 个协作时区"
        case let .invalidParticipantHours(label): return "工作时间无效：\(label)"
        case .invalidImportLimit: return "导入限制必须大于零"
        }
    }
}

struct VeilTemplateAnalysis: Equatable, Sendable {
    let variables: [String]
    let malformed: Bool
}

enum VeilDiffKind: String, Equatable, Sendable {
    case unchanged
    case added
    case removed
}

struct VeilDiffLine: Equatable, Sendable {
    let kind: VeilDiffKind
    let text: String
}

struct VeilMergeResult: Equatable, Sendable {
    let text: String
    let hasConflict: Bool
}

struct VeilTimeZoneParticipant: Equatable, Sendable {
    let label: String
    let timeZoneIdentifier: String
    let preferredStartHour: Int
    let preferredEndHour: Int
}

struct VeilMeetingSlot: Equatable, Sendable {
    let date: Date
    let comfortableParticipantCount: Int
    let totalParticipantCount: Int
    let localTimes: [String]
}

struct VeilImportItem: Equatable, Sendable {
    let name: String
    let byteCount: Int64
}

enum VeilImportSeverity: String, Equatable, Sendable {
    case warning
    case blocking
}

struct VeilImportIssue: Equatable, Sendable {
    let itemName: String?
    let severity: VeilImportSeverity
    let message: String
}

struct VeilImportPreflight: Equatable, Sendable {
    let itemCount: Int
    let totalBytes: Int64
    let issues: [VeilImportIssue]

    var canImport: Bool { !issues.contains { $0.severity == .blocking } }
}

enum VeilProductivityEngine {
    private static let maxTextBytes = 65_536
    private static let maxDiffLines = 400

    static func analyzeTemplate(_ template: String) throws -> VeilTemplateAnalysis {
        guard template.utf8.count <= maxTextBytes else { throw VeilProductivityError.templateTooLarge }
        var variables: [String] = []
        var seen = Set<String>()
        var cursor = template.startIndex
        var malformed = false

        while let open = template.range(of: "{{", range: cursor..<template.endIndex) {
            guard let close = template.range(of: "}}", range: open.upperBound..<template.endIndex) else {
                malformed = true
                break
            }
            let raw = template[open.upperBound..<close.lowerBound]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let valid = !raw.isEmpty && raw.unicodeScalars.allSatisfy {
                CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-. ")).contains($0)
            }
            if !valid {
                malformed = true
            } else if seen.insert(raw).inserted {
                variables.append(raw)
            }
            cursor = close.upperBound
        }
        if template[cursor...].contains("}}") { malformed = true }
        return VeilTemplateAnalysis(variables: variables, malformed: malformed)
    }

    static func renderTemplate(_ template: String, values: [String: String]) throws -> String {
        let analysis = try analyzeTemplate(template)
        guard !analysis.malformed else { throw VeilProductivityError.malformedPlaceholder }
        let missing = analysis.variables.filter { values[$0]?.isEmpty != false }
        guard missing.isEmpty else { throw VeilProductivityError.missingVariables(missing) }
        var output = ""
        var cursor = template.startIndex
        while let open = template.range(of: "{{", range: cursor..<template.endIndex),
              let close = template.range(of: "}}", range: open.upperBound..<template.endIndex) {
            output.append(contentsOf: template[cursor..<open.lowerBound])
            let name = template[open.upperBound..<close.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
            output += values[name] ?? ""
            cursor = close.upperBound
        }
        output.append(contentsOf: template[cursor...])
        return output
    }

    static func diff(old: String, new: String) throws -> [VeilDiffLine] {
        guard old.utf8.count <= maxTextBytes, new.utf8.count <= maxTextBytes else {
            throw VeilProductivityError.diffTooLarge
        }
        let lhs = lines(old)
        let rhs = lines(new)
        guard lhs.count <= maxDiffLines, rhs.count <= maxDiffLines else {
            throw VeilProductivityError.diffTooLarge
        }
        var lcs = Array(repeating: Array(repeating: 0, count: rhs.count + 1), count: lhs.count + 1)
        if !lhs.isEmpty, !rhs.isEmpty {
            for i in stride(from: lhs.count - 1, through: 0, by: -1) {
                for j in stride(from: rhs.count - 1, through: 0, by: -1) {
                    lcs[i][j] = lhs[i] == rhs[j] ? lcs[i + 1][j + 1] + 1 : max(lcs[i + 1][j], lcs[i][j + 1])
                }
            }
        }
        var result: [VeilDiffLine] = []
        var i = 0
        var j = 0
        while i < lhs.count || j < rhs.count {
            if i < lhs.count, j < rhs.count, lhs[i] == rhs[j] {
                result.append(VeilDiffLine(kind: .unchanged, text: lhs[i])); i += 1; j += 1
            } else if j < rhs.count, i == lhs.count || lcs[i][j + 1] >= lcs[i + 1][j] {
                result.append(VeilDiffLine(kind: .added, text: rhs[j])); j += 1
            } else {
                result.append(VeilDiffLine(kind: .removed, text: lhs[i])); i += 1
            }
        }
        return result
    }

    static func threeWayMerge(base: String, local: String, remote: String) throws -> VeilMergeResult {
        guard [base, local, remote].allSatisfy({ $0.utf8.count <= maxTextBytes }) else {
            throw VeilProductivityError.diffTooLarge
        }
        if local == remote { return VeilMergeResult(text: local, hasConflict: false) }
        if local == base { return VeilMergeResult(text: remote, hasConflict: false) }
        if remote == base { return VeilMergeResult(text: local, hasConflict: false) }
        let text = "<<<<<<< 本机\n\(local)\n||||||| 基线\n\(base)\n=======\n\(remote)\n>>>>>>> 对端"
        return VeilMergeResult(text: text, hasConflict: true)
    }

    static func meetingSlots(
        from start: Date,
        participants: [VeilTimeZoneParticipant],
        days: Int = 3,
        limit: Int = 8
    ) throws -> [VeilMeetingSlot] {
        guard !participants.isEmpty else { throw VeilProductivityError.noParticipants }
        guard participants.count <= 24 else { throw VeilProductivityError.tooManyParticipants }
        let resolved: [(VeilTimeZoneParticipant, TimeZone, DateFormatter)] = try participants.map { participant in
            guard (0...23).contains(participant.preferredStartHour),
                  (1...24).contains(participant.preferredEndHour),
                  participant.preferredStartHour < participant.preferredEndHour else {
                throw VeilProductivityError.invalidParticipantHours(participant.label)
            }
            guard let zone = TimeZone(identifier: participant.timeZoneIdentifier) else {
                throw VeilProductivityError.invalidTimeZone(participant.timeZoneIdentifier)
            }
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.timeZone = zone
            formatter.dateFormat = "MM-dd HH:mm"
            return (participant, zone, formatter)
        }
        let horizon = max(1, min(days, 7)) * 48
        let count = max(1, min(limit, 24))
        let aligned = Date(timeIntervalSince1970: ceil(start.timeIntervalSince1970 / 1_800) * 1_800)
        var candidates: [VeilMeetingSlot] = []
        for offset in 0..<horizon {
            let date = aligned.addingTimeInterval(Double(offset * 1_800))
            var localTimes: [String] = []
            var comfortable = 0
            for (participant, zone, formatter) in resolved {
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = zone
                let hour = calendar.component(.hour, from: date)
                let inWindow = participant.preferredStartHour <= hour && hour < participant.preferredEndHour
                if inWindow { comfortable += 1 }
                localTimes.append("\(participant.label) · \(formatter.string(from: date))")
            }
            candidates.append(VeilMeetingSlot(
                date: date,
                comfortableParticipantCount: comfortable,
                totalParticipantCount: resolved.count,
                localTimes: localTimes
            ))
        }
        return candidates.sorted {
            if $0.comfortableParticipantCount != $1.comfortableParticipantCount {
                return $0.comfortableParticipantCount > $1.comfortableParticipantCount
            }
            return $0.date < $1.date
        }.prefix(count).map { $0 }
    }

    static func importPreflight(
        items: [VeilImportItem],
        maximumItems: Int = 500,
        maximumTotalBytes: Int64 = 2_147_483_648,
        allowedExtensions: Set<String> = []
    ) throws -> VeilImportPreflight {
        guard maximumItems > 0, maximumTotalBytes > 0 else { throw VeilProductivityError.invalidImportLimit }
        var issues: [VeilImportIssue] = []
        var seen = Set<String>()
        var total: Int64 = 0
        let normalizedExtensions = Set(allowedExtensions.map { $0.lowercased() })
        if items.count > maximumItems {
            issues.append(VeilImportIssue(itemName: nil, severity: .blocking, message: "文件数超过 \(maximumItems) 个限制"))
        }
        for item in items {
            let name = item.name.precomposedStringWithCanonicalMapping
            let key = name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            if name.isEmpty || name == "." || name == ".." || name.contains("/") || name.contains("\\") || name.contains("\0") {
                issues.append(VeilImportIssue(itemName: item.name, severity: .blocking, message: "文件名不安全"))
            }
            if !seen.insert(key).inserted {
                issues.append(VeilImportIssue(itemName: item.name, severity: .blocking, message: "规范化后文件名重复"))
            }
            if item.byteCount < 0 {
                issues.append(VeilImportIssue(itemName: item.name, severity: .blocking, message: "文件大小无效"))
            } else if item.byteCount == 0 {
                issues.append(VeilImportIssue(itemName: item.name, severity: .warning, message: "空文件"))
            } else if total > Int64.max - item.byteCount {
                issues.append(VeilImportIssue(itemName: nil, severity: .blocking, message: "总大小计算溢出"))
            } else {
                total += item.byteCount
            }
            if !normalizedExtensions.isEmpty {
                let ext = (name as NSString).pathExtension.lowercased()
                if !normalizedExtensions.contains(ext) {
                    issues.append(VeilImportIssue(itemName: item.name, severity: .blocking, message: "不允许的文件类型"))
                }
            }
        }
        if total > maximumTotalBytes {
            issues.append(VeilImportIssue(itemName: nil, severity: .blocking, message: "总大小超过限制"))
        }
        return VeilImportPreflight(itemCount: items.count, totalBytes: total, issues: issues)
    }

    private static func lines(_ text: String) -> [String] {
        text.isEmpty ? [] : text.components(separatedBy: .newlines)
    }
}
