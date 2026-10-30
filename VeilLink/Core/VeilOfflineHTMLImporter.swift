import Foundation
import SwiftSoup

/// Read-only HTML importer. Never uses WKWebView or executes HTML scripts.
/// Import is deliberately initiated from a detached task by the SwiftUI caller.
enum VeilOfflineHTMLImporter {
    static func load(fileURL: URL) throws -> VeilOfflineHTMLDocument {
        guard fileURL.isFileURL else { throw VeilHTMLImportError.unsupportedSource }
        let authorized = fileURL.startAccessingSecurityScopedResource()
        defer { if authorized { fileURL.stopAccessingSecurityScopedResource() } }
        if let size = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size]) as? NSNumber,
           size.int64Value > Int64(VeilHTMLImportPolicy.maximumSourceBytes) {
            throw VeilHTMLImportError.fileTooLarge
        }
        let raw = try Data(contentsOf: fileURL)
        return try parse(raw)
    }

    static func parse(_ input: Data) throws -> VeilOfflineHTMLDocument {
        let decoded = try VeilHTMLImportPolicy.decode(input)
        let dom = try SwiftSoup.parse(decoded)
        let rawTitle = try dom.title().trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove non-content nodes *before* text extraction. Scripts never execute.
        try dom.select("script,style,noscript,template,iframe,object,embed,canvas,svg,form,nav,footer,header").remove()
        guard let body = dom.body() else { throw VeilHTMLImportError.invalidDocument }

        var sections: [String] = []
        sections.reserveCapacity(64)
        var remaining = VeilHTMLImportPolicy.maximumOutputCharacters
        var truncated = false
        for element in try body.select("h1,h2,h3,h4,p,li,blockquote,pre") {
            if sections.count >= VeilHTMLImportPolicy.maximumSections { truncated = true; break }
            let value = try element.text().trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty, value != sections.last else { continue }
            if value.count > remaining {
                if remaining > 0 { sections.append(VeilHTMLImportPolicy.bounded(value, limit: remaining)) }
                truncated = true
                remaining = 0
                break
            }
            sections.append(value)
            remaining -= value.count
        }
        if sections.isEmpty {
            let text = try body.text()
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw VeilHTMLImportError.invalidDocument
            }
            sections.append(VeilHTMLImportPolicy.bounded(text))
            truncated = text.count > VeilHTMLImportPolicy.maximumOutputCharacters
        }

        var links: [VeilOfflineHTMLLink] = []
        var uniqueURLs = Set<String>()
        for element in try body.select("a[href]") {
            if links.count >= VeilHTMLImportPolicy.maximumLinks { truncated = true; break }
            guard let safe = VeilHTMLImportPolicy.safeExternalLink(try element.attr("href")),
                  uniqueURLs.insert(safe).inserted else { continue }
            let rawLabel = try element.text().trimmingCharacters(in: .whitespacesAndNewlines)
            links.append(.init(label: VeilHTMLImportPolicy.bounded(rawLabel.isEmpty ? safe : rawLabel, limit: 90), address: safe))
        }
        return VeilOfflineHTMLDocument(
            title: VeilHTMLImportPolicy.bounded(rawTitle.isEmpty ? "无标题资料" : rawTitle, limit: 140),
            sections: sections,
            links: links,
            truncated: truncated
        )
    }
}
