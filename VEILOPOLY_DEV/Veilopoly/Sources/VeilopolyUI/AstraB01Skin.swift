#if os(iOS) && canImport(SwiftUI)
import SwiftUI

/// A visual skin only. Real button actions, disabled states, keyboard focus,
/// and the authoritative GameState remain owned by the existing SwiftUI host.
public struct AstraB01ButtonStyle: ButtonStyle {
 @Environment(\.isEnabled) private var isEnabled
 public init() {}

 public func makeBody(configuration: Configuration) -> some View {
  configuration.label
   .font(.system(size: 14, weight: .semibold))
   .foregroundColor(Color(red: 0.92, green: 0.95, blue: 0.97))
   .lineLimit(1).minimumScaleFactor(0.78)
   // Astra's decorative icon is already baked into the left part of this skin.
   .padding(.leading, 36).padding(.trailing, 8)
   .frame(maxWidth: .infinity, minHeight: 44)
   .background {
    Image(AstraB01AssetNames.primaryButton(enabled: isEnabled,
                                           pressed: configuration.isPressed), bundle: .module)
     .resizable(capInsets: EdgeInsets(top: 12, leading: 42, bottom: 12, trailing: 12),
                resizingMode: .stretch)
     .allowsHitTesting(false)
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
  Image(kind == .action ? AstraB01AssetNames.actionPanel : AstraB01AssetNames.glassPanel,
        bundle: .module)
   .resizable(capInsets: EdgeInsets(top: 24, leading: 24, bottom: 24, trailing: 24),
              resizingMode: .stretch)
   .allowsHitTesting(false)
   .accessibilityHidden(true)
 }
}

public struct AstraB01FeedbackSkin: View {
 let error: Bool
 public init(error: Bool) { self.error = error }
 public var body: some View {
  Image(error ? AstraB01AssetNames.feedbackError : AstraB01AssetNames.feedbackPositive,
        bundle: .module)
   .resizable(capInsets: EdgeInsets(top: 12, leading: 44, bottom: 12, trailing: 12),
              resizingMode: .stretch)
   .allowsHitTesting(false).accessibilityHidden(true)
 }
}
#endif
