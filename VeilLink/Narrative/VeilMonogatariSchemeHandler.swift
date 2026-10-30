import Foundation
import WebKit

/// Bounded read-only access to the bundled web game.
/// No Documents, chat messages, BLE state, secrets, or external network paths.
final class VeilMonogatariSchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "veilnovel"
    static let host = "game"
    private static let chunkSize = 256 * 1024
    private static let maximumSize: UInt64 = 256 * 1024 * 1024
    private let root = Bundle.main.resourceURL?.appendingPathComponent("VisualNovelBundle", isDirectory: true)
    private let lock = NSLock()
    private var active = Set<ObjectIdentifier>()
    private var cancelled = Set<ObjectIdentifier>()

    private func stopped(_ token: ObjectIdentifier) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled.contains(token)
    }

    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        let token = ObjectIdentifier(task as AnyObject)
        lock.lock()
        active.insert(token)
        lock.unlock()
        defer {
            lock.lock()
            active.remove(token)
            cancelled.remove(token)
            lock.unlock()
        }

        guard let url = task.request.url,
              url.scheme == Self.scheme, url.host == Self.host,
              url.user == nil, url.password == nil, url.query == nil,
              let directory = root else { fail(task, code: 403); return }

        let relative = url.path.isEmpty || url.path == "/" ? "index.html" : String(url.path.dropFirst())
        let parts = relative.split(separator: "/", omittingEmptySubsequences: false)
        guard !parts.isEmpty, parts.allSatisfy({
            !$0.isEmpty && $0 != "." && $0 != ".." &&
            !$0.contains("\\") && !$0.contains("%") &&
            !$0.contains(":") && !$0.contains("\0")
        }) else { fail(task, code: 403); return }

        let base = directory.standardizedFileURL.resolvingSymlinksInPath()
        let file = parts.reduce(base) { $0.appendingPathComponent(String($1)) }
            .standardizedFileURL.resolvingSymlinksInPath()
        guard file.path.hasPrefix(base.path + "/"),
              let attrs = try? FileManager.default.attributesOfItem(atPath: file.path),
              attrs[.type] as? FileAttributeType == .typeRegular,
              let number = attrs[.size] as? NSNumber else {
            fail(task, code: 404); return
        }

        let byteCount = number.uint64Value
        guard byteCount <= Self.maximumSize, byteCount <= UInt64(Int.max) else {
            fail(task, code: 413); return
        }
        let requestRange = task.request.value(forHTTPHeaderField: "Range")
        if byteCount == 0 {
            guard requestRange == nil else { fail(task, code: 416); return }
            if let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1",
                                             headerFields: ["Content-Length": "0", "Content-Type": Self.mime(file.pathExtension)]) {
                if !stopped(token) { task.didReceive(response); task.didFinish() }
            } else { fail(task, code: 500) }
            return
        }
        guard let range = VeilNovelRangeParser.resolve(requestRange, fileLength: Int(byteCount)) else {
            fail(task, code: 416); return
        }
        var headers = ["Content-Type": Self.mime(file.pathExtension),
                       "Content-Length": String(range.count),
                       "Accept-Ranges": "bytes",
                       "Cache-Control": "no-cache"]
        if requestRange != nil { headers["Content-Range"] = range.contentRange }
        guard let response = HTTPURLResponse(url: url, statusCode: requestRange == nil ? 200 : 206,
                                             httpVersion: "HTTP/1.1", headerFields: headers) else {
            fail(task, code: 500); return
        }
        do {
            let handle = try FileHandle(forReadingFrom: file)
            defer { handle.closeFile() }
            handle.seek(toFileOffset: UInt64(range.first))
            if stopped(token) { return }
            task.didReceive(response)
            var remaining = range.count
            while remaining > 0 {
                if stopped(token) { return }
                let chunk = handle.readData(ofLength: min(remaining, Self.chunkSize))
                if chunk.isEmpty {
                    if !stopped(token) { fail(task, code: 500) }
                    return
                }
                if stopped(token) { return }
                task.didReceive(chunk)
                remaining -= chunk.count
            }
            if !stopped(token) { task.didFinish() }
        } catch {
            if !stopped(token) { task.didFailWithError(error) }
        }
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {
        let token = ObjectIdentifier(task as AnyObject)
        lock.lock()
        if active.contains(token) { cancelled.insert(token) }
        lock.unlock()
    }

    private func fail(_ task: WKURLSchemeTask, code: Int) {
        task.didFailWithError(NSError(domain: "VeilNovelResource", code: code,
                                      userInfo: [NSLocalizedDescriptionKey: "Bundled game resource error"]))
    }
    private static func mime(_ ext: String) -> String {
        switch ext.lowercased() {
        case "html": return "text/html"
        case "css": return "text/css"
        case "js", "mjs": return "application/javascript"
        case "json": return "application/json"
        case "svg": return "image/svg+xml"
        case "png": return "image/png"
        case "jpeg", "jpg": return "image/jpeg"
        case "webp": return "image/webp"
        case "gif": return "image/gif"
        case "woff": return "font/woff"
        case "woff2": return "font/woff2"
        case "ttf": return "font/ttf"
        case "otf": return "font/otf"
        case "mp3": return "audio/mpeg"
        case "m4a": return "audio/mp4"
        case "mp4": return "video/mp4"
        case "webm": return "video/webm"
        case "wav": return "audio/wav"
        default: return "application/octet-stream"
        }
    }
}
