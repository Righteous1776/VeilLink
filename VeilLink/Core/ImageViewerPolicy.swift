import Foundation

/// On-demand large-image decode policy. Chat bubbles keep their cheap device-sized thumbnails;
/// a larger decode is only requested after the user explicitly opens the full-screen viewer.
enum ImageViewerPolicy {
    static func maxPixelSize(
        machineIdentifier: String,
        previewMaxPixelSize: Int,
        highDefinitionOverride: Bool
    ) -> Int {
        if highDefinitionOverride { return 4_096 }

        switch machineIdentifier {
        case "iPhone8,4": // iPhone SE (1st generation)
            return 1_536
        case "iPhone9,1", "iPhone9,2", "iPhone9,3", "iPhone9,4": // iPhone 7 / 7 Plus
            return 2_048
        case "iPhone12,8": // iPhone SE (2nd generation)
            return 2_560
        case "iPhone14,2": // iPhone 13 Pro
            return 3_072
        case "iPad13,1", "iPad13,2": // iPad Air 4
            return 3_072
        default:
            return min(3_072, max(1_536, previewMaxPixelSize * 2))
        }
    }

    static var currentMaxPixelSize: Int {
        let overrides = PerformanceOverrideStore.shared.snapshot()
        return maxPixelSize(
            machineIdentifier: VeilDevicePerformance.machineIdentifier,
            previewMaxPixelSize: VeilDevicePerformance.current.imagePreviewMaxPixelSize,
            highDefinitionOverride: overrides.isEnabled && overrides.highDefinitionPreview
        )
    }
}
