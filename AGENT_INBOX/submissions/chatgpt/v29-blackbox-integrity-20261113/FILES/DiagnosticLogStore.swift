import Combine
import CryptoKit
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

private struct DiagnosticExportFileSummary: Codable {
    let name: String
    let byteCount: Int
    let eventCount: Int
    let invalidLineCount: Int
    let firstSequence: UInt64?
    let lastSequence: UInt64?
    let sha256: String
}

private struct DiagnosticExportManifest: Codable {
    let format: String
    let version: Int
    let generatedAt: Date
    let appVersion: String
    let build: String
    let runtimeSessionID: String
    let eventCount: Int
    /// Diagnostic store's in-memory window can be larger than what disk retained.
    /// Never present this as the number of records actually included in the ZIP.
    let inMemoryEventCount: Int
    let invalidLineCount: Int
    let logWriteFailureCount: Int
    let droppedUnpersistedLineCount: Int
    let unpersistedBytes: Int
    let logFileCount: Int
    let files: [DiagnosticExportFileSummary]
    let retentionBytes: Int
    let privacy: String
}

private struct DiagnosticExportIndex: Codable {
    let generatedAt: Date
    let firstTimestamp: Date?
    let lastTimestamp: Date?
    let eventCount: Int
    let invalidLineCount: Int
    let files: [DiagnosticExportFileSummary]
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
    // Keep diagnostics failures from turning into an unbounded RAM leak.
    private let maxPendingBufferBytes = 4 * 1_024 * 1_024
    private var logWriteFailureCount = 0
    private var droppedUnpersistedLineCount = 0
    private var nextPersistRetryUptime: TimeInterval = 0
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
                // Bound RAM during a five-second disk retry backoff as well.
                self.trimPendingBufferUnsafe()
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
        let staging = fileManager.temporaryDirectory
            .appendingPathComponent("VeilLink-Diagnostics-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: staging) }

        // Take the exact log-file snapshot on the serial writer queue. Copying
        // outside this barrier races the logger's append/rotation and can mix
        // different generations of runtime.N.jsonl in one archive.
        let logURLs = try logQueue.sync { () throws -> [URL] in
            flushPendingBuffer(force: true)
            let sources = orderedLogURLsForReading()
            for source in sources {
                try fileManager.copyItem(
                    at: source,
                    to: staging.appendingPathComponent(source.lastPathComponent)
                )
            }
            return sources.map { staging.appendingPathComponent($0.lastPathComponent) }
        }

        let auxiliary = auxiliaryURLs()
        if !auxiliary.isEmpty {
            let destination = staging.appendingPathComponent("Auxiliary", isDirectory: true)
            try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
            for source in auxiliary {
                try fileManager.copyItem(at: source, to: destination.appendingPathComponent(source.lastPathComponent))
            }
        }

        // Index and manifest derive from copied files only, never recentEntries.
        // In particular, 2,000 entries in memory do not imply 2,000 records
        // survived file rotation or failed writes on an iOS 15 device.
        let index = try makeExportIndex(from: logURLs)
        let manifest = DiagnosticExportManifest(
            format: "VeilLinkDiagnostics",
            version: 2,
            generatedAt: Date(),
            appVersion: VeilBuildInfo.shortVersion,
            build: VeilBuildInfo.build,
            runtimeSessionID: runtimeSessionID,
            eventCount: index.eventCount,
            inMemoryEventCount: recentEntries.count,
            invalidLineCount: index.invalidLineCount,
            logWriteFailureCount: withStateLock { logWriteFailureCount },
            droppedUnpersistedLineCount: withStateLock { droppedUnpersistedLineCount },
            unpersistedBytes: withStateLock { pendingBuffer.count },
            logFileCount: logURLs.count,
            files: index.files,
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

    /// Read exactly what was staged for the ZIP, not the in-memory cache.
    /// Streaming 64 KiB chunks avoids allocating a second ~16 MB log image
    /// while an older 2 GB RAM device is preparing its crash report.
    @MainActor
    private func makeExportIndex(from stagedLogURLs: [URL]) throws -> DiagnosticExportIndex {
        var categoryCounts: [String: Int] = [:]
        var levelCounts: [String: Int] = [:]
        var firstTimestamp: Date?
        var lastTimestamp: Date?
        var totalEvents = 0
        var totalInvalidLines = 0
        var files: [DiagnosticExportFileSummary] = []

        for url in stagedLogURLs {
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            var hasher = SHA256()
            var pendingLine = Data()
            var droppingOversizedLine = false
            var fileEvents = 0
            var invalidLines = 0
            var fileFirstSequence: UInt64?
            var fileLastSequence: UInt64?
            var byteCount = 0

            func consumeLine(_ bytes: Data) {
                guard !bytes.isEmpty else { return }
                guard let entry = try? decoder.decode(DiagnosticLogEntry.self, from: bytes) else {
                    invalidLines += 1
                    return
                }
                fileEvents += 1
                totalEvents += 1
                categoryCounts[entry.category.rawValue, default: 0] += 1
                levelCounts[entry.level.rawValue, default: 0] += 1
                if let old = firstTimestamp {
                    firstTimestamp = min(old, entry.timestamp)
                } else {
                    firstTimestamp = entry.timestamp
                }
                if let old = lastTimestamp {
                    lastTimestamp = max(old, entry.timestamp)
                } else {
                    lastTimestamp = entry.timestamp
                }
                if fileFirstSequence == nil { fileFirstSequence = entry.sequence }
                fileLastSequence = entry.sequence
            }

            while let chunk = try handle.read(upToCount: 65_536), !chunk.isEmpty {
                byteCount += chunk.count
                hasher.update(data: chunk)
                var segmentStart = chunk.startIndex
                for index in chunk.indices where chunk[index] == 0x0A {
                    if !droppingOversizedLine {
                        pendingLine.append(contentsOf: chunk[segmentStart..<index])
                        if pendingLine.count > 65_536 { invalidLines += 1 }
                        else { consumeLine(pendingLine) }
                    }
                    pendingLine.removeAll(keepingCapacity: true)
                    droppingOversizedLine = false
                    segmentStart = chunk.index(after: index)
                }
                if !droppingOversizedLine && segmentStart < chunk.endIndex {
                    pendingLine.append(contentsOf: chunk[segmentStart..<chunk.endIndex])
                    if pendingLine.count > 65_536 {
                        // A corrupt line must not become unbounded export RAM.
                        invalidLines += 1
                        pendingLine.removeAll(keepingCapacity: true)
                        droppingOversizedLine = true
                    }
                }
            }
            if !pendingLine.isEmpty && !droppingOversizedLine {
                // The writer always terminates JSONL with \n. An incomplete
                // last record is diagnostically useful but never counted valid.
                invalidLines += 1
            }
            totalInvalidLines += invalidLines
            let sha256 = hasher.finalize().map { String(format: "%02x", Int($0)) }.joined()
            files.append(DiagnosticExportFileSummary(
                name: url.lastPathComponent, byteCount: byteCount,
                eventCount: fileEvents, invalidLineCount: invalidLines,
                firstSequence: fileFirstSequence, lastSequence: fileLastSequence,
                sha256: sha256
            ))
        }
        return DiagnosticExportIndex(
            generatedAt: Date(),
            firstTimestamp: firstTimestamp,
            lastTimestamp: lastTimestamp,
            eventCount: totalEvents,
            invalidLineCount: totalInvalidLines,
            files: files,
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

    private func flushPendingBuffer(force: Bool = false) {
        stateLock.lock()
        flushPendingBufferUnsafe(force: force)
        stateLock.unlock()
        notifyObservers()
    }

    private func flushPendingBufferUnsafe(force: Bool = false) {
        flushTask?.cancel()
        flushTask = nil
        guard !pendingBuffer.isEmpty else { return }
        // Repeated disk-protection or storage errors must not cause a new
        // flush/rotation attempt on every UI event.
        if !force && ProcessInfo.processInfo.systemUptime < nextPersistRetryUptime {
            scheduleFlushUnsafe()
            return
        }

        let data = pendingBuffer
        let rotated = rotateIfNeeded(incomingBytes: data.count)
        guard append(data) else {
            // A failed FileHandle write used to silently discard the ENTIRE
            // pending buffer, giving 2,000 cached entries but 72 on disk.
            // Preserve for a later retry, but limit it on low-memory devices.
            logWriteFailureCount += 1
            nextPersistRetryUptime = ProcessInfo.processInfo.systemUptime + 5
            trimPendingBufferUnsafe()
            // Retry asynchronously; don't block the main UI on unavailable disk.
            scheduleFlushUnsafe()
            return
        }
        pendingBuffer.removeAll(keepingCapacity: true)
        nextPersistRetryUptime = 0
        flushesSinceDiskUsageRefresh += 1
        if rotated || flushesSinceDiskUsageRefresh >= 8 {
            refreshDiskUsageUnsafe()
            flushesSinceDiskUsageRefresh = 0
        } else {
            diskUsageBytesStorage = min(retentionBytes, max(0, diskUsageBytesStorage + data.count))
            lastRefreshAtStorage = Date()
        }
    }

    /// Preserve complete JSONL records at the tail of the retry buffer.
    /// This is called under stateLock on the serial logging queue.
    private func trimPendingBufferUnsafe() {
        while pendingBuffer.count > maxPendingBufferBytes {
            guard let newline = pendingBuffer.firstIndex(of: 0x0A) else {
                pendingBuffer.removeAll(keepingCapacity: true)
                droppedUnpersistedLineCount += 1
                break
            }
            pendingBuffer.removeSubrange(pendingBuffer.startIndex...newline)
            droppedUnpersistedLineCount += 1
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

    @discardableResult
    private func append(_ data: Data) -> Bool {
        if !fileManager.fileExists(atPath: currentLogURL.path) {
            do {
                try data.write(
                    to: currentLogURL,
                    options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
                )
                return true
            } catch {
                return false
            }
        }

        do {
            let handle = try FileHandle(forWritingTo: currentLogURL)
            defer { try? handle.close() }
            let originalLength = try handle.seekToEnd()
            do {
                try handle.write(contentsOf: data)
                return true
            } catch {
                // An interrupted append can leave partial JSONL. Best effort
                // rollback prevents duplicate sequence numbers on the retry.
                try? handle.truncate(atOffset: originalLength)
                return false
            }
        } catch {
            // Keep failed data in RAM, never pretend persistence succeeded.
            return false
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
