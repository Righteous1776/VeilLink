import Foundation
import WebKit

/// Read-only iOS 15 local resource transport for the unmodified Monogatari runtime.
/// No access to user documents, chats, keys, BLE, network, or writable directories.
final class VeilMonogatariSchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "veilnovel"
    static let host = "game"
    private static let chunkSize = 256 * 1024
    private static let maxFileBytes: UInt64 = 256 * 1024 * 1024

    private let root = Bundle.main.resourceURL?.appendingPathComponent("VisualNovelBundle", isDirectory: true)
    private let lock = NSLock()
    private var active = Set<ObjectIdentifier>()
    private var cancelled = Set<ObjectIdentifier>()

    private func isCancelled(_ id: ObjectIdentifier) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled.contains(id)
    }

    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        let id = ObjectIdentifier(task as AnyObject)
        lock.lock()
        active.insert(id)
        lock.unlock()
        defer {
            lock.lock()
            active.remove(id)
            cancelled.remove(id)
            lock.unlock()
        }

        guard let url = task.request.url,
              url.scheme == Self.scheme, url.host == Self.host,
              url.user == nil, url.password == nil, url.query == nil,
              let root = root else {
            fail(task, 403)
            return
        }
        let components = (url.path == "/" ? "/index.html" : url.path)
            .split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        guard !components.isEmpty, components.allSatisfy({
            !$0.isEmpty && $0 != "." && $0 != ".." &&
            !$0.contains("\\") && !$0.contains("%") &&
            !$0.contains(":") && !$0.contains("\0")
        }) else {
            fail(task, 403)
            return
        }
        let base = root.standardizedFileURL.resolvingSymlinksInPath()
        let asset = components.reduce(base) { $0.appendingPathComponent($1) }
            .standardizedFileURL.resolvingSymlinksInPath()
        guard asset.path.hasPrefix(base.path + "/"),
              let metadata = try? FileManager.default.attributesOfItem(atPath: asset.path),
              metadata[.type] as? FileAttributeType == .typeRegular,
              let n = metadata[.size] as? NSNumber else {
            fail(task, 404)
            return
        }
        let size = n.uint64Value
        guard size <= Self.maxFileBytes, size <= UInt64(Int.max) else {
            fail(task, 413)
            return
        }
        let rangeRequest = task.request.value(forHTTPHeaderField: "Range")
        if size == 0 {
            guard rangeRequest == nil else { fail(task, 416); return }
            let response = URLResponse(url: url, mimeType: Self.mime(for: asset.pathExtension),
                                       expectedContentLength: 0, textEncodingName: nil)
            if !isCancelled(id) {
                task.didReceive(response)
                task.didFinish()
            }
            return
        }
        guard let range = VeilNovelRangeParser.resolve(rangeRequest, fileLength: Int(size)) else {
            fail(task, 416)
            return
        }
        var headers = [
            "Content-Type": Self.mime(for: asset.pathExtension),
            "Content-Length": String(range.count),
            "Accept-Ranges": "bytes",
            "Cache-Control": "public, max-age=86400"
        ]
        if rangeRequest != nil { headers["Content-Range"] = range.contentRange }
        guard let response = HTTPURLResponse(url: url, statusCode: rangeRequest == nil ? 200 : 206,
                                             httpVersion: "HTTP/1.1", headerFields: headers) else {
            fail(task, 500)
            return
        }

        do {
            let file = try FileHandle(forReadingFrom: asset)
            defer { file.closeFile() }
            file.seek(toFileOffset: UInt64(range.first))
            guard !isCancelled(id) else { return }
            task.didReceive(response)
            var remaining = range.count
            while remaining > 0 {
                if isCancelled(id) { return }
                let chunk = file.readData(ofLength: min(Self.chunkSize, remaining))
                guard !chunk.isEmpty else {
                    task.didFailWithError(NSError(domain: "VeilNovelAssets", code: 500))
                    return
                }
                if isCancelled(id) { return }
                task.didReceive(chunk)
                remaining -= chunk.count
            }
            if !isCancelled(id) { task.didFinish() }
        } catch {
            if !isCancelled(id) { task.didFailWithError(error) }
        }
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {
        let id = ObjectIdentifier(task as AnyObject)
        lock.lock()
        if active.contains(id) { cancelled.insert(id) }
        lock.unlock()
    }

    private func fail(_ task: WKURLSchemeTask, _ code: Int) {
        task.didFailWithError(NSError(domain: "VeilNovelAssets", code: code,
                                      userInfo: [NSLocalizedDescriptionKey: "离线游戏资源读取失败 (\(code))"]))
    }

    private static func mime(for ext: String) -> String {
        switch ext.lowercased() {
        case "html", "htm": return "text/html"
        case "css": return "text/css"
        case "js", "mjs": return "application/javascript"
        case "json", "webmanifest": return "application/json"
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "webp": return "image/webp"
        case "svg": return "image/svg+xml"
        case "gif": return "image/gif"
        case "ico": return "image/x-icon"
        case "woff", "woff2": return "font/woff2"
        case "mp3": return "audio/mpeg"
        case "m4a": return "audio/mp4"
        case "wav": return "audio/wav"
        case "ogg": return "audio/ogg"
        case "mp4", "m4v": return "video/mp4"
        case "webm": return "video/webm"
        default: return "application/octet-stream"
        }
    }
}
