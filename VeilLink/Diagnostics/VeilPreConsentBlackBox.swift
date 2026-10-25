import Foundation
import SwiftUI
import UIKit

/// A deliberately isolated pre-consent diagnostic lane.
/// This must not initialize AppModel, Keychain, SQLite, BLE, LAN, agent or telemetry hooks.
@MainActor
final class VeilPreConsentBlackBox {
    static let shared = VeilPreConsentBlackBox()

    enum Stage: String, Codable {
        case launch
        case onboarding
        case consent
        case startupFailure
    }

    enum Event: String, Codable {
        case systemAppearanceChanged
        case appLaunched
        case rootPresented
        case sceneActive
        case sceneInactive
        case sceneBackground
        case appearanceChanged
        case themeChanged
        case legalShown
        case legalHidden
        case documentSwitched
        case confirmationChanged
        case acknowledgmentFocused
        case acknowledgmentUnfocused
        case signTapped
        case signIncomplete
        case signSaved
        case signStorageFailed
        case startupFailed
        case startupKeyMissing
        case startupKeyUnavailable
        case startupKeyMismatch
        case startupOtherFailure
        case exportRequested
        case exportPrepared
        case exportFailed
    }

    struct Entry: Codable {
        let sequence: Int
        let time: Date
        let event: Event
        let stage: Stage
        let session: String
        let colorMode: String
        let systemAppearance: String
    }

    private struct Export: Codable {
        let format: String
        let schema: Int
        let generatedAt: Date
        let appVersion: String
        let build: String
        let iosVersion: String
        let hardwareClass: String
        let privacy: String
        let entries: [Entry]
    }

    private let directory: URL
    private let eventURL: URL
    private let session = String(UUID().uuidString.prefix(8))
    private let limit = 128
    private(set) var entries: [Entry]

    init(rootDirectory: URL? = nil) {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        directory = rootDirectory ?? base
            .appendingPathComponent("VeilLink", isDirectory: true)
            .appendingPathComponent("PreConsentBlackBox", isDirectory: true)
        eventURL = directory.appendingPathComponent("events.json")
        if let data = try? Data(contentsOf: eventURL),
           let saved = try? JSONDecoder().decode([Entry].self, from: data) {
            entries = Array(saved.suffix(128))
        } else {
            entries = []
        }
    }

    func record(_ event: Event, stage: Stage) {
        let mode = UserDefaults.standard.string(forKey: "appearance.color.mode.v1") ?? "automatic"
        let style: String
        switch UITraitCollection.current.userInterfaceStyle {
        case .dark: style = "dark"
        case .light: style = "light"
        default: style = "unspecified"
        }

        entries.append(Entry(
            sequence: (entries.last?.sequence ?? 0) + 1,
            time: Date(),
            event: event,
            stage: stage,
            session: session,
            colorMode: ["automatic", "light", "dark"].contains(mode) ? mode : "other",
            systemAppearance: style
        ))
        if entries.count > limit { entries.removeFirst(entries.count - limit) }
        // Best-effort diagnostics: NEVER affect legal acceptance or application startup.
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoded = try JSONEncoder().encode(entries)
            try encoded.write(to: eventURL, options: [.atomic, .completeFileProtectionUnlessOpen])
        } catch {
            // Memory ring still supports export if disk is temporarily inaccessible.
        }
    }

    func exportData() throws -> Data {
        let bundle = Bundle.main
        let export = Export(
            format: "VeilLinkPreConsentBlackBox",
            schema: 1,
            generatedAt: Date(),
            appVersion: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?",
            build: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?",
            iosVersion: UIDevice.current.systemVersion,
            hardwareClass: UIDevice.current.model,
            privacy: "Only fixed event names, stage, time, temporary session, appearance mode and OS/build information. No typed text, agreements, identifiers, keys, private messages, network connections, media or prompts.",
            entries: entries
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(export)
    }

    func exportFile() throws -> URL {
        let data = try exportData()
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("VeilLink-PreConsent-\(UUID().uuidString).json")
        try data.write(to: output, options: [.atomic, .completeFileProtectionUnlessOpen])
        return output
    }
}

/// Mounted before the legal gate is satisfied; never calls the normal AppModel-driven exporter.
struct VeilPreConsentBlackBoxButton: View {
    var stage: VeilPreConsentBlackBox.Stage = .consent
    @State private var preparedFile: URL?
    @State private var presentsShare = false
    @State private var exportError: String?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "waveform.path.ecg.rectangle")
            Text("首次启动异常？")
                .font(.system(size: 11, weight: .medium))
            Spacer(minLength: 4)
            Button {
                let box = VeilPreConsentBlackBox.shared
                box.record(.exportRequested, stage: stage)
                do {
                    preparedFile = try box.exportFile()
                    box.record(.exportPrepared, stage: stage)
                    presentsShare = true
                } catch {
                    box.record(.exportFailed, stage: stage)
                    exportError = "无法创建本地诊断文件。请检查设备可用空间。"
                }
            } label: {
                Label("导出临时黑匣子", systemImage: "square.and.arrow.up")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("preconsent.blackbox.export")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color(uiColor: .secondarySystemBackground))
        .sheet(isPresented: $presentsShare) {
            if let preparedFile {
                DiagnosticsExportShareSheet(items: [preparedFile])
            }
        }
        .alert("导出失败", isPresented: Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(exportError ?? "")
        }
    }
}
