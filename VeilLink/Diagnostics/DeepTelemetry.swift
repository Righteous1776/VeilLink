import Foundation
import SwiftUI
import UIKit
import ObjectiveC.runtime

@MainActor
final class DeepTelemetry: ObservableObject {
    static let shared = DeepTelemetry()

    @Published var rawTouchCaptureEnabled: Bool {
        didSet { UserDefaults.standard.set(rawTouchCaptureEnabled, forKey: Self.rawTouchKey) }
    }
    @Published var inputLifecycleCaptureEnabled: Bool {
        didSet { UserDefaults.standard.set(inputLifecycleCaptureEnabled, forKey: Self.inputLifecycleKey) }
    }
    @Published var postInteractionSnapshotsEnabled: Bool {
        didSet { UserDefaults.standard.set(postInteractionSnapshotsEnabled, forKey: Self.postSnapshotKey) }
    }
    @Published var performanceWatchEnabled: Bool {
        didSet { UserDefaults.standard.set(performanceWatchEnabled, forKey: Self.performanceWatchKey) }
    }
    @Published private(set) var currentScreen = "bootstrap"
    @Published private(set) var lastInteractionAt: Date?

    private static let rawTouchKey = "diagnostics.deepTelemetry.rawTouch"
    private static let inputLifecycleKey = "diagnostics.deepTelemetry.inputLifecycle"
    private static let postSnapshotKey = "diagnostics.deepTelemetry.postInteractionSnapshot"
    private static let performanceWatchKey = "diagnostics.deepTelemetry.performanceWatch"

    private let store = DiagnosticLogStore.shared
    private var screenStack: [String] = []
    private var installed = false
    private var observers: [NSObjectProtocol] = []
    private var heartbeatTimer: Timer?
    private var lastHeartbeatAt = Date()
    private var heartbeatCounter = 0
    private var lastSnapshotAt = Date.distantPast

    private init() {
        let defaults = UserDefaults.standard
        rawTouchCaptureEnabled = defaults.object(forKey: Self.rawTouchKey) as? Bool ?? true
        inputLifecycleCaptureEnabled = defaults.object(forKey: Self.inputLifecycleKey) as? Bool ?? true
        postInteractionSnapshotsEnabled = defaults.object(forKey: Self.postSnapshotKey) as? Bool ?? true
        performanceWatchEnabled = defaults.object(forKey: Self.performanceWatchKey) as? Bool ?? true
    }

    func install() {
        guard !installed else {
            UIInteractionProbe.installOnApplicationWindows()
            return
        }
        installed = true
        UIDevice.current.isBatteryMonitoringEnabled = true
        _ = ProcessInfo.processInfo.thermalState
        UIInteractionProbe.installOnApplicationWindows()
        UIActionDispatcherProbe.install()
        UIViewControllerLifecycleProbe.install()
        MetricKitTelemetryReceiver.shared.start()
        installNotificationObservers()
        startHeartbeat()
        captureSystemSnapshot(reason: "telemetry.install")
        captureUIHierarchy(reason: "telemetry.install", force: true)
    }

    func screenAppear(_ name: String, metadata: [String: String] = [:]) {
        let normalized = DiagnosticPrivacyFilter.sanitizeValue(name, limit: 128)
        screenStack.removeAll { $0 == normalized }
        screenStack.append(normalized)
        currentScreen = normalized
        store.log(.info, .ui, event: "ui.screen.appear", screen: currentScreen, metadata: metadata)
        captureUIHierarchy(reason: "screen.appear", force: true)
    }

    func screenDisappear(_ name: String, metadata: [String: String] = [:]) {
        let normalized = DiagnosticPrivacyFilter.sanitizeValue(name, limit: 128)
        store.log(.info, .ui, event: "ui.screen.disappear", screen: normalized, metadata: metadata)
        if let index = screenStack.lastIndex(of: normalized) {
            screenStack.remove(at: index)
        }
        currentScreen = screenStack.last ?? "unknown"
    }

    func setNavigationScreen(_ name: String, metadata: [String: String] = [:]) {
        currentScreen = DiagnosticPrivacyFilter.sanitizeValue(name, limit: 128)
        store.log(.info, .navigation, event: "ui.navigation", screen: currentScreen, metadata: metadata)
        captureUIHierarchy(reason: "navigation", force: true)
    }

    func action(_ action: String, metadata: [String: String] = [:]) {
        lastInteractionAt = Date()
        store.log(.info, .ui, event: "ui.action", screen: currentScreen, message: action, metadata: metadata)
        schedulePostInteractionSnapshot()
    }

    func valueChange(_ name: String, from oldValue: String, to newValue: String, metadata: [String: String] = [:]) {
        var values = metadata
        values["control"] = name
        values["old"] = oldValue
        values["new"] = newValue
        store.log(.info, .ui, event: "ui.value_change", screen: currentScreen, metadata: values)
        schedulePostInteractionSnapshot()
    }

    func presentation(_ name: String, presented: Bool, metadata: [String: String] = [:]) {
        var values = metadata
        values["presentation"] = name
        values["state"] = presented ? "presented" : "dismissed"
        store.log(.info, .navigation, event: "ui.presentation", screen: currentScreen, metadata: values)
        captureUIHierarchy(reason: "presentation", force: true)
    }

    func rawInteraction(
        kind: String,
        point: CGPoint,
        duration: TimeInterval,
        displacement: CGFloat,
        viewDescriptor: [String: String]
    ) {
        guard rawTouchCaptureEnabled else { return }
        lastInteractionAt = Date()
        let secureContext = Self.isSensitiveScreen(currentScreen) || viewDescriptor["secure_context"] == "true"
        var metadata = viewDescriptor
        if secureContext {
            metadata.removeValue(forKey: "frame")
            metadata.removeValue(forKey: "accessibility_id")
            metadata["coordinates"] = "<redacted-secure-context>"
            metadata["secure_context"] = "true"
        } else {
            metadata["x"] = String(format: "%.1f", point.x)
            metadata["y"] = String(format: "%.1f", point.y)
        }
        metadata["duration_ms"] = String(Int(duration * 1_000))
        metadata["displacement"] = secureContext ? "<redacted>" : String(format: "%.1f", displacement)
        store.log(.debug, .ui, event: "ui.raw.\(kind)", screen: currentScreen, metadata: metadata)
        schedulePostInteractionSnapshot()
    }

    func inputEvent(
        _ event: String,
        identifier: String?,
        length: Int,
        secure: Bool,
        metadata: [String: String] = [:]
    ) {
        guard inputLifecycleCaptureEnabled else { return }
        var values = metadata
        values["identifier"] = identifier ?? ""
        values["length"] = String(length)
        values["secure"] = secure ? "true" : "false"
        store.log(.debug, .input, event: event, screen: currentScreen, metadata: values)
    }

    static func isSensitiveScreen(_ screen: String) -> Bool {
        let normalized = screen.lowercased()
        return normalized == "lock"
            || normalized.contains("password")
            || normalized.contains("passcode")
            || normalized.contains("secure_entry")
            || normalized == "owner.unlock"
    }

    static func hasSecureInput(in root: UIView?) -> Bool {
        guard let root else { return false }
        if let field = root as? UITextField, field.isFirstResponder, field.isSecureTextEntry {
            return true
        }
        return root.subviews.contains(where: { hasSecureInput(in: $0) })
    }

    func captureUIHierarchy(reason: String, force: Bool = false) {
        guard postInteractionSnapshotsEnabled || force else { return }
        let now = Date()
        if !force, now.timeIntervalSince(lastSnapshotAt) < 0.25 { return }
        lastSnapshotAt = now

        guard let window = Self.activeWindow else {
            store.log(.debug, .ui, event: "ui.snapshot", screen: currentScreen, metadata: ["reason": reason, "window": "none"])
            return
        }

        let hierarchy = Self.viewControllerHierarchy(root: window.rootViewController)
        let visibleViewCount = Self.visibleViewCount(in: window, limit: 2_500)
        let metadata: [String: String] = [
            "reason": reason,
            "window": String(reflecting: type(of: window)),
            "window_level": String(format: "%.1f", window.windowLevel.rawValue),
            "bounds": "\(Int(window.bounds.width))x\(Int(window.bounds.height))",
            "visible_view_count": String(visibleViewCount),
            "controller_path": hierarchy,
            "first_responder": Self.firstResponderDescriptor(in: window)
        ]
        store.log(.debug, .ui, event: "ui.snapshot", screen: currentScreen, metadata: metadata)
    }

    func captureSystemSnapshot(reason: String, extra: [String: String] = [:]) {
        var metadata = SystemDiagnosticsSnapshot.capture()
        metadata["reason"] = reason
        metadata.merge(extra) { _, new in new }
        store.log(.info, .system, event: "system.snapshot", screen: currentScreen, metadata: metadata)
    }

    func recordOwnerAccess(unlocked: Bool) {
        store.log(
            .info,
            .security,
            event: unlocked ? "owner.unlocked" : "owner.locked",
            screen: currentScreen
        )
    }

    private func schedulePostInteractionSnapshot() {
        guard postInteractionSnapshotsEnabled else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { [weak self] in
            self?.captureUIHierarchy(reason: "post-interaction")
        }
    }

    private func installNotificationObservers() {
        let center = NotificationCenter.default

        observers.append(center.addObserver(forName: UIApplication.userDidTakeScreenshotNotification, object: nil, queue: .main) { _ in
            Task { @MainActor in
                DeepTelemetry.shared.store.log(.info, .ui, event: "ui.screenshot_taken", screen: DeepTelemetry.shared.currentScreen)
            }
        })
        observers.append(center.addObserver(forName: UIApplication.protectedDataDidBecomeAvailableNotification, object: nil, queue: .main) { _ in
            Task { @MainActor in DeepTelemetry.shared.store.log(.info, .system, event: "system.protected_data.available") }
        })
        observers.append(center.addObserver(forName: UIApplication.protectedDataWillBecomeUnavailableNotification, object: nil, queue: .main) { _ in
            Task { @MainActor in DeepTelemetry.shared.store.log(.info, .system, event: "system.protected_data.unavailable") }
        })
        observers.append(center.addObserver(forName: UIApplication.significantTimeChangeNotification, object: nil, queue: .main) { _ in
            Task { @MainActor in DeepTelemetry.shared.captureSystemSnapshot(reason: "significant-time-change") }
        })
        observers.append(center.addObserver(forName: NSNotification.Name.NSProcessInfoPowerStateDidChange, object: nil, queue: .main) { _ in
            Task { @MainActor in DeepTelemetry.shared.captureSystemSnapshot(reason: "power-state-change") }
        })
        observers.append(center.addObserver(forName: ProcessInfo.thermalStateDidChangeNotification, object: nil, queue: .main) { _ in
            Task { @MainActor in DeepTelemetry.shared.captureSystemSnapshot(reason: "thermal-state-change") }
        })
        observers.append(center.addObserver(forName: UIDevice.orientationDidChangeNotification, object: nil, queue: .main) { _ in
            Task { @MainActor in
                DeepTelemetry.shared.store.log(.debug, .ui, event: "ui.orientation_change", screen: DeepTelemetry.shared.currentScreen, metadata: SystemDiagnosticsSnapshot.orientationMetadata())
                DeepTelemetry.shared.captureUIHierarchy(reason: "orientation", force: true)
            }
        })
        observers.append(center.addObserver(forName: UIDevice.batteryLevelDidChangeNotification, object: nil, queue: .main) { _ in
            Task { @MainActor in DeepTelemetry.shared.captureSystemSnapshot(reason: "battery-level-change") }
        })
        observers.append(center.addObserver(forName: UIDevice.batteryStateDidChangeNotification, object: nil, queue: .main) { _ in
            Task { @MainActor in DeepTelemetry.shared.captureSystemSnapshot(reason: "battery-state-change") }
        })
        observers.append(center.addObserver(forName: UIScreen.brightnessDidChangeNotification, object: nil, queue: .main) { _ in
            Task { @MainActor in DeepTelemetry.shared.captureSystemSnapshot(reason: "brightness-change") }
        })
        observers.append(center.addObserver(forName: UIContentSizeCategory.didChangeNotification, object: nil, queue: .main) { _ in
            Task { @MainActor in DeepTelemetry.shared.captureSystemSnapshot(reason: "content-size-category-change") }
        })
        observers.append(center.addObserver(forName: NSLocale.currentLocaleDidChangeNotification, object: nil, queue: .main) { _ in
            Task { @MainActor in DeepTelemetry.shared.captureSystemSnapshot(reason: "locale-change") }
        })
        observers.append(center.addObserver(forName: NSNotification.Name.NSSystemTimeZoneDidChange, object: nil, queue: .main) { _ in
            Task { @MainActor in DeepTelemetry.shared.captureSystemSnapshot(reason: "timezone-change") }
        })
        observers.append(center.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { notification in
            Task { @MainActor in DeepTelemetry.shared.recordKeyboard(notification, showing: true) }
        })
        observers.append(center.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { notification in
            Task { @MainActor in DeepTelemetry.shared.recordKeyboard(notification, showing: false) }
        })
        observers.append(center.addObserver(forName: UITextField.textDidBeginEditingNotification, object: nil, queue: .main) { notification in
            Task { @MainActor in DeepTelemetry.shared.recordTextField(notification.object, event: "input.field.begin") }
        })
        observers.append(center.addObserver(forName: UITextField.textDidChangeNotification, object: nil, queue: .main) { notification in
            Task { @MainActor in DeepTelemetry.shared.recordTextField(notification.object, event: "input.field.change") }
        })
        observers.append(center.addObserver(forName: UITextField.textDidEndEditingNotification, object: nil, queue: .main) { notification in
            Task { @MainActor in DeepTelemetry.shared.recordTextField(notification.object, event: "input.field.end") }
        })
        observers.append(center.addObserver(forName: UITextView.textDidBeginEditingNotification, object: nil, queue: .main) { notification in
            Task { @MainActor in DeepTelemetry.shared.recordTextView(notification.object, event: "input.textview.begin") }
        })
        observers.append(center.addObserver(forName: UITextView.textDidChangeNotification, object: nil, queue: .main) { notification in
            Task { @MainActor in DeepTelemetry.shared.recordTextView(notification.object, event: "input.textview.change") }
        })
        observers.append(center.addObserver(forName: UITextView.textDidEndEditingNotification, object: nil, queue: .main) { notification in
            Task { @MainActor in DeepTelemetry.shared.recordTextView(notification.object, event: "input.textview.end") }
        })
    }

    private func recordTextField(_ object: Any?, event: String) {
        guard let field = object as? UITextField else { return }
        inputEvent(
            event,
            identifier: field.accessibilityIdentifier,
            length: field.text?.count ?? 0,
            secure: field.isSecureTextEntry,
            metadata: [
                "keyboard_type": String(field.keyboardType.rawValue),
                "return_key": String(field.returnKeyType.rawValue),
                "enabled": field.isEnabled ? "true" : "false"
            ]
        )
    }

    private func recordTextView(_ object: Any?, event: String) {
        guard let view = object as? UITextView else { return }
        inputEvent(
            event,
            identifier: view.accessibilityIdentifier,
            length: view.text?.count ?? 0,
            secure: false,
            metadata: [
                "keyboard_type": String(view.keyboardType.rawValue),
                "editable": view.isEditable ? "true" : "false"
            ]
        )
    }

    private func recordKeyboard(_ notification: Notification, showing: Bool) {
        var metadata: [String: String] = ["state": showing ? "show" : "hide"]
        if let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
            metadata["frame"] = "\(Int(frame.origin.x)),\(Int(frame.origin.y)),\(Int(frame.width)),\(Int(frame.height))"
        }
        if let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double {
            metadata["animation_ms"] = String(Int(duration * 1_000))
        }
        store.log(.debug, .input, event: "input.keyboard", screen: currentScreen, metadata: metadata)
    }

    private func startHeartbeat() {
        heartbeatTimer?.invalidate()
        lastHeartbeatAt = Date()
        heartbeatCounter = 0
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                let telemetry = DeepTelemetry.shared
                let now = Date()
                let delta = now.timeIntervalSince(telemetry.lastHeartbeatAt)
                telemetry.lastHeartbeatAt = now
                telemetry.heartbeatCounter += 1

                if telemetry.performanceWatchEnabled, delta > 1.35 {
                    telemetry.store.log(
                        .warning,
                        .performance,
                        event: "performance.main_thread_stall",
                        screen: telemetry.currentScreen,
                        metadata: ["delay_ms": String(Int((delta - 1.0) * 1_000))]
                    )
                }

                if telemetry.heartbeatCounter % 30 == 0 {
                    telemetry.captureSystemSnapshot(reason: "periodic-30s")
                }
            }
        }
        if let heartbeatTimer {
            RunLoop.main.add(heartbeatTimer, forMode: .common)
        }
    }

    private static var activeWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }
            .flatMap(\.windows)
            .first(where: { $0.isKeyWindow })
            ?? UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first(where: { !$0.isHidden && $0.alpha > 0 })
    }

    private static func viewControllerHierarchy(root: UIViewController?) -> String {
        guard let root else { return "none" }
        var path: [String] = []
        var current: UIViewController? = root
        var safety = 0
        while let controller = current, safety < 16 {
            path.append(String(reflecting: type(of: controller)))
            if let presented = controller.presentedViewController {
                current = presented
            } else if let navigation = controller as? UINavigationController, let visible = navigation.visibleViewController {
                current = visible
            } else if let tab = controller as? UITabBarController, let selected = tab.selectedViewController {
                current = selected
            } else {
                current = controller.children.last
            }
            safety += 1
        }
        return path.joined(separator: " > ")
    }

    private static func visibleViewCount(in root: UIView, limit: Int) -> Int {
        var count = 0
        var stack: [UIView] = [root]
        while let view = stack.popLast(), count < limit {
            guard !view.isHidden, view.alpha > 0.01 else { continue }
            count += 1
            stack.append(contentsOf: view.subviews)
        }
        return count
    }

    private static func firstResponderDescriptor(in root: UIView) -> String {
        if root.isFirstResponder {
            return describeView(root)["view_class"] ?? "unknown"
        }
        for child in root.subviews {
            let value = firstResponderDescriptor(in: child)
            if value != "none" { return value }
        }
        return "none"
    }

    static func describeView(_ view: UIView?) -> [String: String] {
        guard let view else { return ["hit_view": "none"] }
        var metadata: [String: String] = [
            "view_class": String(reflecting: type(of: view)),
            "accessibility_id": view.accessibilityIdentifier ?? "",
            "enabled": view.isUserInteractionEnabled ? "true" : "false",
            "hidden": view.isHidden ? "true" : "false",
            "alpha": String(format: "%.2f", view.alpha),
            "frame": "\(Int(view.frame.origin.x)),\(Int(view.frame.origin.y)),\(Int(view.frame.width)),\(Int(view.frame.height))"
        ]

        if let control = view as? UIControl {
            metadata["control_enabled"] = control.isEnabled ? "true" : "false"
            metadata["control_selected"] = control.isSelected ? "true" : "false"
            metadata["control_highlighted"] = control.isHighlighted ? "true" : "false"
        }
        if let field = view as? UITextField {
            metadata["secure_input"] = field.isSecureTextEntry ? "true" : "false"
            metadata["input_length"] = String(field.text?.count ?? 0)
        }
        if let textView = view as? UITextView {
            metadata["input_length"] = String(textView.text?.count ?? 0)
        }

        var chain: [String] = []
        var ancestor: UIView? = view
        var depth = 0
        while let current = ancestor, depth < 7 {
            chain.append(String(reflecting: type(of: current)))
            ancestor = current.superview
            depth += 1
        }
        metadata["view_path"] = chain.joined(separator: " < ")
        return metadata
    }
}

private struct TelemetryScreenModifier: ViewModifier {
    let name: String
    let metadata: [String: String]

    func body(content: Content) -> some View {
        content
            .onAppear { DeepTelemetry.shared.screenAppear(name, metadata: metadata) }
            .onDisappear { DeepTelemetry.shared.screenDisappear(name, metadata: metadata) }
    }
}

extension View {
    func telemetryScreen(_ name: String, metadata: [String: String] = [:]) -> some View {
        modifier(TelemetryScreenModifier(name: name, metadata: metadata))
    }
}

@MainActor
private enum SystemDiagnosticsSnapshot {
    static func capture() -> [String: String] {
        let device = UIDevice.current
        let process = ProcessInfo.processInfo
        let screen = UIScreen.main
        let availableCapacity = try? URL(fileURLWithPath: NSHomeDirectory())
            .resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            .volumeAvailableCapacityForImportantUsage

        var metadata: [String: String] = [
            "device_model": device.model,
            "system_name": device.systemName,
            "system_version": device.systemVersion,
            "idfv": device.identifierForVendor?.uuidString ?? "unavailable",
            "battery_level": device.batteryLevel < 0 ? "unknown" : String(format: "%.3f", device.batteryLevel),
            "battery_state": batteryState(device.batteryState),
            "low_power": process.isLowPowerModeEnabled ? "true" : "false",
            "thermal": thermalState(process.thermalState),
            "processor_count": String(process.processorCount),
            "active_processor_count": String(process.activeProcessorCount),
            "physical_memory": String(process.physicalMemory),
            "system_uptime": String(format: "%.3f", process.systemUptime),
            "screen_bounds": "\(Int(screen.bounds.width))x\(Int(screen.bounds.height))",
            "screen_native_bounds": "\(Int(screen.nativeBounds.width))x\(Int(screen.nativeBounds.height))",
            "screen_scale": String(format: "%.2f", screen.scale),
            "screen_native_scale": String(format: "%.2f", screen.nativeScale),
            "brightness": String(format: "%.3f", screen.brightness),
            "locale": Locale.current.identifier,
            "timezone": TimeZone.current.identifier,
            "preferred_languages": Locale.preferredLanguages.prefix(4).joined(separator: ","),
            "render_profile": VeilRenderProfile.diagnosticLabel,
            "device_profile": VeilDevicePerformance.diagnosticLabel,
            "reduce_motion": UIAccessibility.isReduceMotionEnabled ? "true" : "false",
            "reduce_transparency": UIAccessibility.isReduceTransparencyEnabled ? "true" : "false",
            "bold_text": UIAccessibility.isBoldTextEnabled ? "true" : "false",
            "app_state": appState(UIApplication.shared.applicationState)
        ]
        if let availableCapacity {
            metadata["disk_available_important"] = String(availableCapacity)
        }
        metadata.merge(orientationMetadata()) { _, new in new }
        return metadata
    }

    static func orientationMetadata() -> [String: String] {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let orientation = scene?.interfaceOrientation
        return [
            "interface_orientation": orientation.map(interfaceOrientation) ?? "unknown",
            "device_orientation": deviceOrientation(UIDevice.current.orientation)
        ]
    }

    private static func appState(_ state: UIApplication.State) -> String {
        switch state {
        case .active: return "active"
        case .inactive: return "inactive"
        case .background: return "background"
        @unknown default: return "unknown"
        }
    }

    private static func batteryState(_ state: UIDevice.BatteryState) -> String {
        switch state {
        case .unknown: return "unknown"
        case .unplugged: return "unplugged"
        case .charging: return "charging"
        case .full: return "full"
        @unknown default: return "unknown"
        }
    }

    private static func thermalState(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: return "nominal"
        case .fair: return "fair"
        case .serious: return "serious"
        case .critical: return "critical"
        @unknown default: return "unknown"
        }
    }

    private static func interfaceOrientation(_ value: UIInterfaceOrientation) -> String {
        switch value {
        case .unknown: return "unknown"
        case .portrait: return "portrait"
        case .portraitUpsideDown: return "portrait_upside_down"
        case .landscapeLeft: return "landscape_left"
        case .landscapeRight: return "landscape_right"
        @unknown default: return "unknown"
        }
    }

    private static func deviceOrientation(_ value: UIDeviceOrientation) -> String {
        switch value {
        case .unknown: return "unknown"
        case .portrait: return "portrait"
        case .portraitUpsideDown: return "portrait_upside_down"
        case .landscapeLeft: return "landscape_left"
        case .landscapeRight: return "landscape_right"
        case .faceUp: return "face_up"
        case .faceDown: return "face_down"
        @unknown default: return "unknown"
        }
    }
}



@MainActor
private enum UIViewControllerLifecycleProbe {
    private static var installed = false

    static func install() {
        guard !installed else { return }
        installed = true
        exchange(
            #selector(UIViewController.viewDidAppear(_:)),
            #selector(UIViewController.vl_viewDidAppear(_:))
        )
        exchange(
            #selector(UIViewController.viewDidDisappear(_:)),
            #selector(UIViewController.vl_viewDidDisappear(_:))
        )
    }

    private static func exchange(_ originalSelector: Selector, _ replacementSelector: Selector) {
        guard
            let original = class_getInstanceMethod(UIViewController.self, originalSelector),
            let replacement = class_getInstanceMethod(UIViewController.self, replacementSelector)
        else { return }
        method_exchangeImplementations(original, replacement)
    }
}

extension UIViewController {
    @objc fileprivate func vl_viewDidAppear(_ animated: Bool) {
        vl_viewDidAppear(animated)
        let navigationDepth = navigationController?.viewControllers.count ?? 0
        DiagnosticLogStore.shared.log(
            .debug,
            .ui,
            event: "ui.controller.appear",
            screen: DeepTelemetry.shared.currentScreen,
            metadata: [
                "controller": String(reflecting: type(of: self)),
                "presentation_style": String(modalPresentationStyle.rawValue),
                "navigation_depth": String(navigationDepth),
                "view_bounds": "\(Int(view.bounds.width))x\(Int(view.bounds.height))",
                "animated": String(animated)
            ]
        )
        DeepTelemetry.shared.captureUIHierarchy(reason: "controller.appear", force: true)
    }

    @objc fileprivate func vl_viewDidDisappear(_ animated: Bool) {
        DiagnosticLogStore.shared.log(
            .debug,
            .ui,
            event: "ui.controller.disappear",
            screen: DeepTelemetry.shared.currentScreen,
            metadata: [
                "controller": String(reflecting: type(of: self)),
                "presentation_style": String(modalPresentationStyle.rawValue),
                "animated": String(animated)
            ]
        )
        vl_viewDidDisappear(animated)
    }
}

@MainActor
private enum UIActionDispatcherProbe {
    private static var installed = false

    static func install() {
        guard !installed else { return }
        installed = true
        guard
            let original = class_getInstanceMethod(
                UIApplication.self,
                #selector(UIApplication.sendAction(_:to:from:for:))
            ),
            let replacement = class_getInstanceMethod(
                UIApplication.self,
                #selector(UIApplication.vl_sendAction(_:to:from:for:))
            )
        else { return }
        method_exchangeImplementations(original, replacement)
    }
}

extension UIApplication {
    @objc fileprivate func vl_sendAction(
        _ action: Selector,
        to target: Any?,
        from sender: Any?,
        for event: UIEvent?
    ) -> Bool {
        if DeepTelemetry.shared.rawTouchCaptureEnabled {
            var metadata: [String: String] = [
                "selector": NSStringFromSelector(action),
                "sender_class": sender.map { String(reflecting: type(of: $0)) } ?? "nil",
                "target_class": target.map { String(reflecting: type(of: $0)) } ?? "nil",
                "event_type": event.map { String($0.type.rawValue) } ?? "none"
            ]
            let secureContext = DeepTelemetry.isSensitiveScreen(DeepTelemetry.shared.currentScreen)
                || DeepTelemetry.hasSecureInput(in: (sender as? UIView)?.window)
            if let view = sender as? UIView, !secureContext {
                metadata.merge(DeepTelemetry.describeView(view)) { _, new in new }
            } else if secureContext {
                metadata["secure_context"] = "true"
            }
            DiagnosticLogStore.shared.log(
                .debug,
                .ui,
                event: "ui.dispatch_action",
                screen: DeepTelemetry.shared.currentScreen,
                metadata: metadata
            )
        }
        return vl_sendAction(action, to: target, from: sender, for: event)
    }
}

@MainActor
private enum UIInteractionProbe {
    static func installOnApplicationWindows() {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .filter { !$0.isHidden }

        for window in windows where !(window.gestureRecognizers ?? []).contains(where: { $0 is PassiveTouchRecorder }) {
            let recorder = PassiveTouchRecorder()
            recorder.cancelsTouchesInView = false
            recorder.delaysTouchesBegan = false
            recorder.delaysTouchesEnded = false
            window.addGestureRecognizer(recorder)
        }
    }
}

@MainActor
private final class PassiveTouchRecorder: UIGestureRecognizer {
    private var startedAt: TimeInterval = 0
    private var startPoint = CGPoint.zero
    private var lastPoint = CGPoint.zero
    private var maximumDisplacement: CGFloat = 0
    private var maximumTouchCount = 0

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch = touches.first, let view else { return }
        startedAt = ProcessInfo.processInfo.systemUptime
        startPoint = touch.location(in: view)
        lastPoint = startPoint
        maximumDisplacement = 0
        maximumTouchCount = max(touches.count, event.allTouches?.count ?? touches.count)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch = touches.first, let view else { return }
        lastPoint = touch.location(in: view)
        maximumDisplacement = max(maximumDisplacement, hypot(lastPoint.x - startPoint.x, lastPoint.y - startPoint.y))
        maximumTouchCount = max(maximumTouchCount, event.allTouches?.count ?? touches.count)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch = touches.first, let view else {
            state = .failed
            return
        }
        lastPoint = touch.location(in: view)
        maximumDisplacement = max(maximumDisplacement, hypot(lastPoint.x - startPoint.x, lastPoint.y - startPoint.y))
        let duration = max(0, ProcessInfo.processInfo.systemUptime - startedAt)
        let window = view as? UIWindow ?? view.window
        let hit = window?.hitTest(lastPoint, with: nil)
        let kind: String
        if maximumTouchCount > 1 {
            kind = "multitouch"
        } else if maximumDisplacement < 14 && duration < 0.9 {
            kind = "tap"
        } else if maximumDisplacement < 14 {
            kind = "long_press"
        } else {
            kind = Self.gestureKind(from: startPoint, to: lastPoint)
        }
        let point = lastPoint
        var descriptor = DeepTelemetry.describeView(hit)
        descriptor["touch_count"] = String(maximumTouchCount)
        descriptor["secure_context"] = DeepTelemetry.hasSecureInput(in: window) ? "true" : "false"

        Task { @MainActor in
            DeepTelemetry.shared.rawInteraction(
                kind: kind,
                point: point,
                duration: duration,
                displacement: maximumDisplacement,
                viewDescriptor: descriptor
            )
        }
        state = .failed
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        state = .failed
    }

    override func reset() {
        super.reset()
        startedAt = 0
        startPoint = .zero
        lastPoint = .zero
        maximumDisplacement = 0
        maximumTouchCount = 0
    }

    private static func gestureKind(from start: CGPoint, to end: CGPoint) -> String {
        let dx = end.x - start.x
        let dy = end.y - start.y
        if abs(dx) > abs(dy) {
            return dx >= 0 ? "swipe_right" : "swipe_left"
        }
        return dy >= 0 ? "swipe_down" : "swipe_up"
    }
}
