import Combine
import Foundation
import ZIPFoundation

enum DiagnosticLogLevel: String, Codable, CaseIterable, Identifiable {
    case debug
    case info
    case warning
    case error
    case critical

    var id: String { rawValue }

    var rank: Int {
        switch self {
        case .debug: return 0
        case .info: return 1
        case .warning: return 2
        case .error: return 3
        case .critical: return 4
        }
    }

    var title: String {
        switch self {
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARN"
        case .error: return "ERROR"
        case .critical: return "CRITICAL"
        }
    }
}

enum DiagnosticLogCategory: String, Codable, CaseIterable, Identifiable {
    case app
    case ui
    case navigation
    case input
    case bluetooth
    case session
    case storage
    case security
    case media
    case agent
    case a9
    case performance
    case stress
    case system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .app: return "APP"
        case .ui: return "UI"
        case .navigation: return "NAV"
        case .input: return "INPUT"
        case .bluetooth: return "BLE"
        case .session: return "SESSION"
        case .storage: return "STORAGE"
        case .security: return "SECURITY"
        case .media: return "MEDIA"
        case .agent: return "AGENT"
        case .a9: return "A9"
        case .performance: return "PERF"
        case .stress: return "STRESS"
        case .system: return "SYSTEM"
        }
    }
}

struct DiagnosticLogEntry: Codable, Identifiable, Hashable {
    let schemaVersion: Int
    let id: String
    let sequence: UInt64
    let timestamp: Date
    let uptimeMilliseconds: UInt64
    let sessionID: String
    let level: DiagnosticLogLevel
    let category: DiagnosticLogCategory
    let event: String
    let screen: String?
    let message: String
    let metadata: [String: String]
}

private struct DiagnosticExportManifest: Codable {
    let format: String
    let version: Int
    let generatedAt: Date
    let appVersion: String
    let build: String
    let runtimeSessionID: String
    let eventCount: Int
    let logFileCount: Int
    let retentionBytes: Int
    let privacy: String
}

private struct DiagnosticExportIndex: Codable {
    let generatedAt: Date
    let firstTimestamp: Date?
    let lastTimestamp: Date?
    let eventCount: Int
    let categoryCounts: [String: Int]
    let levelCounts: [String: Int]
    let currentScreen: String
}

final class DiagnosticLogStore: ObservableObject, @unchecked Sendable {
    static let shared = DiagnosticLogStore()

    let objectWillChange = ObservableObjectPublisher()

    private let logQueue = DispatchQueue(label: "veil.diagnostics.log", qos: .utility)
    private let stateLock = NSLock()
    private var recentEntriesStorage: [DiagnosticLogEntry] = []
    private var diskUsageBytesStorage = 0
    private var lastRefreshAtStorage: Date?
    private var observerNotificationPending = false

    private let fileManager = FileManager.default
    private let rootDirectory: URL
    private let auxiliaryDirectory: URL
    private let currentLogURL: URL
    private let maxFileBytes = 2_000_000
    private let rotatedFileCount = 7
    private let maxRecentEntries = 2_000
    private let maxAuxiliaryBytes = 24 * 1_024 * 1_024
    private let flushThresholdBytes = 256 * 1_024
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var nextSequence: UInt64 = 1
    private var pendingBuffer = Data()
    private var flushTask: Task<Void, Never>?
    private var flushesSinceDiskUsageRefresh = 0

    let runtimeSessionID: String

    var recentEntries: [DiagnosticLogEntry] {
        withStateLock { recentEntriesStorage }
    }

    var diskUsageBytes: Int {
        withStateLock { diskUsageBytesStorage }
    }

    var lastRefreshAt: Date? {
        withStateLock { lastRefreshAtStorage }
    }

    init(rootDirectory: URL? = nil) {
        runtimeSessionID = String(UUID().uuidString.prefix(8)).uppercased()

        let resolvedRoot: URL
        if let rootDirectory {
            resolvedRoot = rootDirectory
        } else {
            let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? fileManager.temporaryDirectory
            resolvedRoot = base
                .appendingPathComponent("VeilLink", isDirectory: true)
                .appendingPathComponent("Diagnostics", isDirectory: true)
        }
        self.rootDirectory = resolvedRoot
        auxiliaryDirectory = resolvedRoot.appendingPathComponent("Auxiliary", isDirectory: true)
        currentLogURL = resolvedRoot.appendingPathComponent("runtime.jsonl")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        try? fileManager.createDirectory(at: resolvedRoot, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: auxiliaryDirectory, withIntermediateDirectories: true)
        protectDirectory()
        loadRecentEntriesFromDisk()
    }

    var diskUsageText: String {
        ByteCountFormatter.string(fromByteCount: Int64(diskUsageBytes), countStyle: .file)
    }

    var retentionBytes: Int {
        maxFileBytes * (rotatedFileCount + 1) + maxAuxiliaryBytes
    }

    var retentionText: String {
        ByteCountFormatter.string(fromByteCount: Int64(retentionBytes), countStyle: .file)
    }

    var exportedFileCount: Int {
        existingLogURLs().count
    }

    func log(
        _ level: DiagnosticLogLevel,
        _ category: DiagnosticLogCategory,
        event: String,
        screen: String? = nil,
        message: String = "",
        metadata: [String: String] = [:]
    ) {
        logQueue.async { [weak self] in
            guard let self else { return }
            self.stateLock.lock()
            let entry = DiagnosticLogEntry(
                schemaVersion: 2,
                id: UUID().uuidString,
                sequence: self.nextSequence,
                timestamp: Date(),
                uptimeMilliseconds: UInt64(ProcessInfo.processInfo.systemUptime * 1_000),
                sessionID: self.runtimeSessionID,
                level: level,
                category: category,
                event: DiagnosticPrivacyFilter.sanitizeValue(event, limit: 128),
                screen: screen.map { DiagnosticPrivacyFilter.sanitizeValue($0, limit: 128) },
                message: DiagnosticPrivacyFilter.sanitizeValue(message, limit: 2_048),
                metadata: DiagnosticPrivacyFilter.sanitizeMetadata(metadata)
            )
            self.nextSequence &+= 1

            self.recentEntriesStorage.append(entry)
            if self.recentEntriesStorage.count > self.maxRecentEntries {
                self.recentEntriesStorage.removeFirst(self.recentEntriesStorage.count - self.maxRecentEntries)
            }

            if let encoded = try? self.encoder.encode(entry) {
                self.pendingBuffer.append(encoded)
                self.pendingBuffer.append(0x0A)
                if self.pendingBuffer.count >= self.flushThresholdBytes {
                    self.flushPendingBufferUnsafe()
                } else {
                    self.scheduleFlushUnsafe()
                }
            }
            self.stateLock.unlock()
            self.notifyObservers()
        }
    }

    func refreshFromDisk() {
        logQueue.async { [weak self] in
            self?.flushPendingBuffer()
            self?.loadRecentEntriesFromDisk()
        }
    }

    func clear() {
        logQueue.sync {
            stateLock.lock()
            flushTask?.cancel()
            flushTask = nil
            pendingBuffer.removeAll(keepingCapacity: false)
            flushesSinceDiskUsageRefresh = 0
            for url in allLogURLs() {
                try? fileManager.removeItem(at: url)
            }
            for url in auxiliaryURLs() {
                try? fileManager.removeItem(at: url)
            }
            recentEntriesStorage.removeAll(keepingCapacity: false)
            diskUsageBytesStorage = 0
            nextSequence = 1
            lastRefreshAtStorage = Date()
            stateLock.unlock()
        }
        notifyObservers()
    }

    @MainActor
    func exportBundle(context: String, extraFiles: [String: Data] = [:]) throws -> URL {
        logQueue.sync { flushPendingBuffer() }

        let staging = fileManager.temporaryDirectory
            .appendingPathComponent("VeilLink-Diagnostics-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: staging) }

        let logURLs = existingLogURLs()
        for source in logURLs {
            try fileManager.copyItem(
                at: source,
                to: staging.appendingPathComponent(source.lastPathComponent)
            )
        }

        let auxiliary = auxiliaryURLs()
        if !auxiliary.isEmpty {
            let destination = staging.appendingPathComponent("Auxiliary", isDirectory: true)
            try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
            for source in auxiliary {
                try fileManager.copyItem(at: source, to: destination.appendingPathComponent(source.lastPathComponent))
            }
        }

        let index = makeExportIndex()
        let manifest = DiagnosticExportManifest(
            format: "VeilLinkDiagnostics",
            version: 2,
            generatedAt: Date(),
            appVersion: VeilBuildInfo.shortVersion,
            build: VeilBuildInfo.build,
            runtimeSessionID: runtimeSessionID,
            eventCount: recentEntries.count,
            logFileCount: logURLs.count,
            retentionBytes: retentionBytes,
            privacy: "No message plaintext, media payload, password/PIN, private/session key, pairing code or AI prompt is intentionally recorded. Technical identifiers may be included for correlation."
        )

        let prettyEncoder = JSONEncoder()
        prettyEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        prettyEncoder.dateEncodingStrategy = .iso8601
        try prettyEncoder.encode(manifest).write(
            to: staging.appendingPathComponent("manifest.json"),
            options: [.atomic, .completeFileProtection]
        )
        try prettyEncoder.encode(index).write(
            to: staging.appendingPathComponent("event-index.json"),
            options: [.atomic, .completeFileProtection]
        )

        let safeContext = DiagnosticPrivacyFilter.sanitizeValue(context, limit: 160_000)
        try Data(safeContext.utf8).write(
            to: staging.appendingPathComponent("runtime-context.txt"),
            options: [.atomic, .completeFileProtection]
        )

        for (rawName, data) in extraFiles {
            let name = safeExportFileName(rawName)
            try data.write(
                to: staging.appendingPathComponent(name),
                options: [.atomic, .completeFileProtection]
            )
        }

        let privacy = """
        VeilLink Deep Telemetry / Black Box

        Intended use: owner-authorized local debugging and incident reconstruction.

        Included technical identifiers may contain the local device ID, IDFV, local identity IDs,
        BLE transport UUIDs, conversation IDs, build/device/OS details and UI structural metadata.

        Intentionally excluded: chat/message plaintext, typed text contents, image/media payloads,
        passwords, app-lock PINs, identity private keys, session keys, pairing codes and AI prompts.

        Text input telemetry records field type/state and character length only, never the content.
        Generic UI touch telemetry records coordinates, view classes and accessibility identifiers,
        but does not scrape arbitrary accessibility labels or rendered text.

        Review this package before sharing outside your own debugging workflow.
        """
        try Data(privacy.utf8).write(
            to: staging.appendingPathComponent("PRIVACY.txt"),
            options: [.atomic, .completeFileProtection]
        )

        let destination = fileManager.temporaryDirectory
            .appendingPathComponent(
                VeilExportFileName.make(prefix: "VeilLink-DeepTelemetry-", suffix: ".zip")
            )
        try fileManager.zipItem(at: staging, to: destination, shouldKeepParent: false)
        return destination
    }

    @discardableResult
    func storeAuxiliaryArtifact(prefix: String, fileExtension: String, data: Data) -> String? {
        guard !data.isEmpty, data.count <= 8 * 1_024 * 1_024 else { return nil }
        let result: String? = logQueue.sync {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"
            let safePrefix = safeExportFileName(prefix)
            let safeExtension = safeExportFileName(fileExtension).replacingOccurrences(of: ".", with: "")
            let name = "\(safePrefix)-\(formatter.string(from: Date())).\(safeExtension.isEmpty ? "bin" : safeExtension)"
            let url = auxiliaryDirectory.appendingPathComponent(name)
            do {
                try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
                trimAuxiliaryArtifacts(maxFiles: 24, maxBytes: maxAuxiliaryBytes)
                refreshDiskUsage()
                return name
            } catch {
                return nil
            }
        }
        notifyObservers()
        return result
    }

    @MainActor
    private func makeExportIndex() -> DiagnosticExportIndex {
        let entries = recentEntries
        var categoryCounts: [String: Int] = [:]
        var levelCounts: [String: Int] = [:]
        for entry in entries {
            categoryCounts[entry.category.rawValue, default: 0] += 1
            levelCounts[entry.level.rawValue, default: 0] += 1
        }
        return DiagnosticExportIndex(
            generatedAt: Date(),
            firstTimestamp: entries.first?.timestamp,
            lastTimestamp: entries.last?.timestamp,
            eventCount: entries.count,
            categoryCounts: categoryCounts,
            levelCounts: levelCounts,
            currentScreen: DeepTelemetry.shared.currentScreen
        )
    }

    private func scheduleFlushUnsafe() {
        guard flushTask == nil else { return }
        flushTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            self?.logQueue.async { [weak self] in self?.flushPendingBuffer() }
        }
    }

    private func flushPendingBuffer() {
        stateLock.lock()
        flushPendingBufferUnsafe()
        stateLock.unlock()
        notifyObservers()
    }

    private func flushPendingBufferUnsafe() {
        flushTask?.cancel()
        flushTask = nil
        guard !pendingBuffer.isEmpty else { return }

        let data = pendingBuffer
        pendingBuffer.removeAll(keepingCapacity: true)
        let rotated = rotateIfNeeded(incomingBytes: data.count)
        append(data)
        flushesSinceDiskUsageRefresh += 1
        if rotated || flushesSinceDiskUsageRefresh >= 8 {
            refreshDiskUsageUnsafe()
            flushesSinceDiskUsageRefresh = 0
        } else {
            diskUsageBytesStorage = min(retentionBytes, max(0, diskUsageBytesStorage + data.count))
            lastRefreshAtStorage = Date()
        }
    }

    private func loadRecentEntriesFromDisk() {
        stateLock.lock()
        loadRecentEntriesFromDiskUnsafe()
        stateLock.unlock()
        notifyObservers()
    }

    private func loadRecentEntriesFromDiskUnsafe() {
        var loaded: [DiagnosticLogEntry] = []
        for url in orderedLogURLsForReading() {
            guard let data = try? Data(contentsOf: url),
                  let string = String(data: data, encoding: .utf8) else { continue }
            for rawLine in string.split(separator: "\n", omittingEmptySubsequences: true) {
                guard let lineData = String(rawLine).data(using: .utf8),
                      let entry = try? decoder.decode(DiagnosticLogEntry.self, from: lineData) else { continue }
                loaded.append(entry)
            }
        }
        if loaded.count > maxRecentEntries {
            loaded = Array(loaded.suffix(maxRecentEntries))
        }
        recentEntriesStorage = loaded
        nextSequence = (loaded.last?.sequence ?? 0) &+ 1
        lastRefreshAtStorage = Date()
        refreshDiskUsageUnsafe()
    }

    private func protectDirectory() {
        try? fileManager.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: rootDirectory.path
        )
    }

    private func append(_ data: Data) {
        if !fileManager.fileExists(atPath: currentLogURL.path) {
            try? data.write(
                to: currentLogURL,
                options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
            )
            return
        }

        do {
            let handle = try FileHandle(forWritingTo: currentLogURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } catch {
            // Diagnostics must never become a new source of runtime failure.
        }
    }

    @discardableResult
    private func rotateIfNeeded(incomingBytes: Int) -> Bool {
        let currentBytes = fileSize(currentLogURL)
        guard currentBytes + incomingBytes > maxFileBytes else { return false }

        let oldest = rotatedURL(rotatedFileCount)
        try? fileManager.removeItem(at: oldest)

        if rotatedFileCount > 1 {
            for index in stride(from: rotatedFileCount - 1, through: 1, by: -1) {
                let source = rotatedURL(index)
                let destination = rotatedURL(index + 1)
                if fileManager.fileExists(atPath: source.path) {
                    try? fileManager.removeItem(at: destination)
                    try? fileManager.moveItem(at: source, to: destination)
                }
            }
        }

        if fileManager.fileExists(atPath: currentLogURL.path) {
            let destination = rotatedURL(1)
            try? fileManager.removeItem(at: destination)
            try? fileManager.moveItem(at: currentLogURL, to: destination)
        }
        return true
    }

    private func refreshDiskUsage() {
        stateLock.lock()
        refreshDiskUsageUnsafe()
        stateLock.unlock()
    }

    private func refreshDiskUsageUnsafe() {
        diskUsageBytesStorage = existingLogURLs().reduce(0) { $0 + fileSize($1) }
            + auxiliaryURLs().reduce(0) { $0 + fileSize($1) }
        lastRefreshAtStorage = Date()
    }

    private func fileSize(_ url: URL) -> Int {
        (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
    }

    private func rotatedURL(_ index: Int) -> URL {
        rootDirectory.appendingPathComponent("runtime.\(index).jsonl")
    }

    private func allLogURLs() -> [URL] {
        [currentLogURL] + (1...rotatedFileCount).map(rotatedURL)
    }

    private func existingLogURLs() -> [URL] {
        allLogURLs().filter { fileManager.fileExists(atPath: $0.path) }
    }

    private func orderedLogURLsForReading() -> [URL] {
        let rotated = stride(from: rotatedFileCount, through: 1, by: -1).map(rotatedURL)
        return (rotated + [currentLogURL]).filter { fileManager.fileExists(atPath: $0.path) }
    }

    private func auxiliaryURLs() -> [URL] {
        ((try? fileManager.contentsOfDirectory(
            at: auxiliaryDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        )) ?? []).filter { !$0.hasDirectoryPath }
    }

    private func trimAuxiliaryArtifacts(maxFiles: Int, maxBytes: Int) {
        var urls = auxiliaryURLs().sorted {
            let lhs = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rhs = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return lhs > rhs
        }
        var total = urls.reduce(0) { $0 + fileSize($1) }
        while urls.count > maxFiles || total > maxBytes {
            guard let oldest = urls.popLast() else { break }
            total -= fileSize(oldest)
            try? fileManager.removeItem(at: oldest)
        }
    }

    private func withStateLock<T>(_ body: () -> T) -> T {
        stateLock.lock()
        defer { stateLock.unlock() }
        return body()
    }

    private func notifyObservers() {
        stateLock.lock()
        guard !observerNotificationPending else {
            stateLock.unlock()
            return
        }
        observerNotificationPending = true
        stateLock.unlock()

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.stateLock.lock()
            self.observerNotificationPending = false
            self.stateLock.unlock()
            self.objectWillChange.send()
        }
    }

    private func safeExportFileName(_ raw: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        let scalars = raw.unicodeScalars.map { allowed.contains($0) ? Character(String($0)) : "_" }
        let value = String(scalars)
        return value.isEmpty ? "extra.bin" : String(value.prefix(128))
    }
}

enum DiagnosticPrivacyFilter {
    private static let sensitiveKeyFragments = [
        "password", "passwd", "passcode", "pin", "private_key", "privatekey",
        "session_key", "sessionkey", "secret", "auth_token", "accesstoken",
        "access_token", "refresh_token", "pairing_code", "pairingcode",
        "message_body", "message_text", "plaintext", "typed_text", "prompt",
        "media_payload", "image_payload", "attachment_payload", "raw_audio",
        "raw_video"
    ]

    static func sanitizeMetadata(_ metadata: [String: String]) -> [String: String] {
        var output: [String: String] = [:]
        for (key, value) in metadata.prefix(64) {
            let safeKey = sanitizeValue(key, limit: 80)
            let normalized = safeKey.lowercased().replacingOccurrences(of: "-", with: "_")
            if sensitiveKeyFragments.contains(where: { normalized.contains($0) }) {
                output[safeKey] = "<redacted>"
            } else {
                output[safeKey] = sanitizeValue(value, limit: 1_024)
            }
        }
        return output
    }

    static func sanitizeValue(_ value: String, limit: Int) -> String {
        var result = value
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")

        result = result.replacingOccurrences(
            of: "(?i)(password|passwd|passcode|private[_-]?key|session[_-]?key|secret|pairing[_-]?code)\\s*[:=]\\s*[^ ,;]+",
            with: "$1=<redacted>",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: "[A-Fa-f0-9]{96,}",
            with: "<redacted-long-hex>",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: "[A-Za-z0-9+/]{160,}={0,2}",
            with: "<redacted-long-token>",
            options: .regularExpression
        )

        if result.count > limit {
            result = String(result.prefix(limit)) + "…"
        }
        return result
    }
}
