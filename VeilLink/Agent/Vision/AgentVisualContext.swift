import Foundation

struct AgentVisualContext: Codable, Equatable, Sendable {
    let capturedAt: Date
    let faceCount: Int
    let labels: [String]
    let recognizedText: [String]
    let frameWidth: Int
    let frameHeight: Int

    var compactPromptDescription: String {
        var parts: [String] = []
        if faceCount > 0 { parts.append("画面中检测到约\(faceCount)张人脸") }
        if !labels.isEmpty { parts.append("视觉标签：\(labels.prefix(5).joined(separator: "、"))") }
        if !recognizedText.isEmpty { parts.append("画面文字：\(recognizedText.prefix(3).joined(separator: " / "))") }
        if parts.isEmpty { parts.append("摄像头画面已接入，但当前没有高置信度视觉摘要") }
        return parts.joined(separator: "；")
    }
}
