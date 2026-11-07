import Foundation

/// The same authored UTF-8 Markdown is packaged offline in the SwiftPM UI
/// Resources folder and delivered as a separately typeset PDF. The viewer
/// never modifies GameState, snapshot hashes, networking or trade actions.
public struct VeilopolyManualSection: Identifiable, Equatable {
 public let id: Int
 public let heading: String
 public let body: String
 public init(id: Int, heading: String, body: String) {
  self.id = id
  self.heading = heading
  self.body = body
 }
}

public enum VeilopolyCompleteManual {
 public static let edition = "VLP-MANUAL-V5-R1"
 public static let minimumIOSMajorVersion = 15
 public static let resourceName = "VeilopolyCompleteManual"
 public static var markdown: String {
  guard let url = Bundle.module.url(forResource: resourceName, withExtension: "md"),
        let source = try? String(contentsOf: url, encoding: .utf8) else {
   return "完整说明书资源不可用。请保留当前对局，联系开发者检查安装资源；不要删除存档。"
  }
  return source
 }

 public static func parse(_ source: String) -> [VeilopolyManualSection] {
  var sections: [VeilopolyManualSection] = []
  var heading = "版本及适用说明"
  var lines: [String] = []
  func flush() {
   let body = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
   if !body.isEmpty {
    sections.append(.init(id: sections.count, heading: heading, body: body))
   }
   lines.removeAll(keepingCapacity: true)
  }
  for line in source.components(separatedBy: "\n") {
   if line.hasPrefix("## ") {
    flush()
    heading = String(line.dropFirst(3))
   } else {
    lines.append(line)
   }
  }
  flush()
  return sections
 }
 public static var sections: [VeilopolyManualSection] { parse(markdown) }
 public static func filtered(_ query: String) -> [VeilopolyManualSection] {
  let key = query.trimmingCharacters(in: .whitespacesAndNewlines)
  guard !key.isEmpty else { return sections }
  return sections.filter {
   $0.heading.localizedCaseInsensitiveContains(key) ||
   $0.body.localizedCaseInsensitiveContains(key)
  }
 }
}
