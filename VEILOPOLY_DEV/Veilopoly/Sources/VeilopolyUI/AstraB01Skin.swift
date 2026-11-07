#if os(iOS) && canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit

/// Astra B01 sources are exported as @2x pixels but copied into SwiftPM
/// without an @2x filename suffix. Explicit scale preserves design-point
/// sizes and keeps nine-slice cap insets in *points*, not raw pixels.
/// UI-only image decode; no engine or renderer ACK side effects.
@MainActor
public enum AstraB01Artwork {
 private static let cache: NSCache<NSString, UIImage> = {
  let cache = NSCache<NSString, UIImage>()
  cache.countLimit = 24
  return cache
 }()

 public static func image(_ name: String) -> Image {
  if let cached = cache.object(forKey: name as NSString) {
   return Image(uiImage: cached)
  }
  guard let url = Bundle.module.url(forResource: name, withExtension: "png"),
        let raw = UIImage(contentsOfFile: url.path),
        let cgImage = raw.cgImage else {
   return Image(name, bundle: .module)
  }
  let scaled = UIImage(cgImage: cgImage, scale: 2, orientation: raw.imageOrientation)
  cache.setObject(scaled, forKey: name as NSString)
  return Image(uiImage: scaled)
 }
}

/// Decorative textures never intercept the Button's actual touch target.
/// Disabled status and press visual are read from native SwiftUI state.
public struct AstraB01ButtonStyle: ButtonStyle {
 @Environment(\.isEnabled) private var isEnabled
 private let secondary: Bool
 public init(secondary: Bool = false) { self.secondary = secondary }

 public func makeBody(configuration: Configuration) -> some View {
  let image = secondary
   ? AstraB01AssetNames.secondaryButton(enabled: isEnabled, pressed: configuration.isPressed)
   : AstraB01AssetNames.primaryButton(enabled: isEnabled, pressed: configuration.isPressed)
  return configuration.label
   .font(.system(size: 14, weight: .semibold))
   .foregroundColor(Color(red: 0.92, green: 0.95, blue: 0.97))
   .lineLimit(1).minimumScaleFactor(0.78)
   .padding(.leading, 36).padding(.trailing, 8)
   .frame(maxWidth: .infinity, minHeight: 44)
   .background {
    AstraB01Artwork.image(image)
     .resizable(capInsets: EdgeInsets(top: 12, leading: 42, bottom: 12, trailing: 12),
                resizingMode: .stretch)
     .allowsHitTesting(false)
     .accessibilityHidden(true)
   }
   .contentShape(Rectangle())
   .accessibilityAddTraits(.isButton)
 }
}

public struct AstraB01PanelSkin: View {
 public enum Kind { case action, glass }
 let kind: Kind
 public init(_ kind: Kind = .action) { self.kind = kind }
 public var body: some View {
  AstraB01Artwork.image(kind == .action ? AstraB01AssetNames.actionPanel : AstraB01AssetNames.glassPanel)
   .resizable(capInsets: EdgeInsets(top: 24, leading: 24, bottom: 24, trailing: 24),
              resizingMode: .stretch)
   .allowsHitTesting(false)
   .accessibilityHidden(true)
 }
}

public struct AstraB01PlayerSkin: View {
 private let key: String
 public init(_ key: String) { self.key = key }
 public var body: some View {
  AstraB01Artwork.image(key)
   .resizable(capInsets: EdgeInsets(top: 16, leading: 52, bottom: 16, trailing: 16),
              resizingMode: .stretch)
   .allowsHitTesting(false)
   .accessibilityHidden(true)
 }
}

public struct AstraB01FeedbackSkin: View {
 let error: Bool
 public init(error: Bool) { self.error = error }
 public var body: some View {
  AstraB01Artwork.image(error ? AstraB01AssetNames.feedbackError : AstraB01AssetNames.feedbackPositive)
   .resizable(capInsets: EdgeInsets(top: 12, leading: 44, bottom: 12, trailing: 12),
              resizingMode: .stretch)
   .allowsHitTesting(false).accessibilityHidden(true)
 }
}
#endif
