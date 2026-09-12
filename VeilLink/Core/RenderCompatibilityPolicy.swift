import Foundation

/// Pure policy for selecting the reduced compositor path. Kept separate from SwiftUI/UIKit
/// so the decision can be tested in the Linux-side CI simulation.
enum RenderCompatibilityPolicy {
    private static let legacyMachines: Set<String> = [
        "iPhone9,1", "iPhone9,3", // iPhone 7
        "iPhone9,2", "iPhone9,4"  // iPhone 7 Plus
    ]

    static func shouldUseLegacyCompositor(machineIdentifier: String, osMajorVersion: Int) -> Bool {
        osMajorVersion <= 15 && legacyMachines.contains(machineIdentifier)
    }
}
