import Foundation

/// Determines the *safe destination* of a file after the provider copy has
/// reached the durable inbox. File suffix alone is never enough to authorize
/// backup restoration or mutation of board-learning databases.
enum VeilUnifiedImportRoute: Equatable {
    case backup
    case html
    case boardLearning(MiniGameKind)
    case image
    case retained(String)

    var destinationTitle: String {
        switch self {
        case .backup: return "加密备份 · 等待密码确认"
        case .html: return "离线 HTML 阅读器"
        case .boardLearning(let game): return game.title + " · 开发训练库（需授权确认）"
        case .image: return "本机图片文件"
        case .retained(let reason): return reason
        }
    }
}

enum VeilUnifiedImportRouter {
    static let maximumBoardProbeBytes = 32 * 1_024 * 1_024

    /// File must already belong to the verified application inbox.
    static func resolve(_ record: VeilFileInboxRecord, at url: URL) -> VeilUnifiedImportRoute {
        switch record.kind {
        case .archive:
            let report = VeilBackupArchiveInspector.inspect(url, verifyAllCRC: false)
            return report.permittedToRestore ? .backup :
                .retained("ZIP 已保存 · 非有效 VeilLink 加密备份，不执行恢复")
        case .boardTrainingCandidate:
            if let game = boardLearningGame(at: url) { return .boardLearning(game) }
            return .retained("JSON 已保存 · 训练包格式或棋种无法确认")
        case .html: return .html
        case .image: return .image
        case .numpy:
            return .retained("NPZ 已保存 · 尚未建立经验证的模型权重加载协议")
        case .text: return .retained("文本数据已保存 · 未自动写入聊天或训练数据库")
        case .pdf: return .retained("PDF 已保存 · 可从收件箱分享")
        case .other: return .retained("文件已保存 · 暂无自动处理器")
        }
    }

    /// Non-mutating format + game-family probe. Full checksum, schema and
    /// move validation still happen in AdaptiveBoardLearningStore.importPackage.
    /// Reject mixed/ambiguous game payloads rather than silently choosing one.
    static func boardLearningGame(at url: URL) -> MiniGameKind? {
        guard let bytes = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize,
              bytes > 0, bytes <= maximumBoardProbeBytes,
              let data = try? Data(contentsOf: url),
              let envelope = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              envelope["format"] as? String == "veillink.board-learning.export.v1",
              envelope["checksumAlgorithm"] as? String == "fnv1a64-canonical-json",
              let payload = envelope["payload"] as? [String: Any],
              payload["schema"] as? Int == 1 else { return nil }

        var kinds = Set<String>()
        if let positions = payload["positions"] as? [String: Any] {
            for key in positions.keys {
                if key.hasPrefix("g:") { kinds.insert("gomoku") }
                else if key.hasPrefix("x:") { kinds.insert("xiangqi") }
                else { return nil }
                if kinds.count > 1 { return nil }
            }
        }
        if let games = payload["recentGames"] as? [[String: Any]] {
            for game in games {
                guard let kind = game["game"] as? String,
                      kind == "gomoku" || kind == "xiangqi" else { return nil }
                kinds.insert(kind)
                if kinds.count > 1 { return nil }
            }
        }
        guard kinds.count == 1, let kind = kinds.first else { return nil }
        return MiniGameKind(rawValue: kind)
    }
}
