import Foundation

/// Pure policy for selecting the reduced compositor path. Kept separate from SwiftUI/UIKit
/// so the decision can be tested in the Linux-side CI simulation.
enum RenderCompatibilityPolicy {
    private static let legacyMachines: Set<String> = [
        "iPhone8,4",              // iPhone SE (1st generation)
        "iPhone9,1", "iPhone9,3", // iPhone 7
        "iPhone9,2", "iPhone9,4"  // iPhone 7 Plus
    ]

    static func shouldUseLegacyCompositor(machineIdentifier: String, osMajorVersion: Int) -> Bool {
        osMajorVersion <= 15 && legacyMachines.contains(machineIdentifier)
    }

    /// iOS 15 SwiftUI can occasionally invalidate a vertically-scrolling content host when
    /// its child width is derived from nested maxWidth/infinity frames during state updates.
    /// Use an explicit viewport-derived width for all iOS 15 builds; this is layout-only and
    /// intentionally broader than the iPhone 7 compositor reduction above.
    static func shouldUseStableScrollLayout(osMajorVersion: Int) -> Bool {
        osMajorVersion <= 15
    }
}
