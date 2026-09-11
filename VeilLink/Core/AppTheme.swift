import SwiftUI

enum VeilTheme {
    static let background = Color(red: 0.035, green: 0.035, blue: 0.045)
    static let elevated = Color(red: 0.075, green: 0.075, blue: 0.09)
    static let panel = Color(red: 0.11, green: 0.105, blue: 0.115)
    static let gold = Color(red: 0.88, green: 0.67, blue: 0.26)
    static let mutedGold = Color(red: 0.55, green: 0.43, blue: 0.23)
    static let text = Color.white.opacity(0.94)
    static let secondaryText = Color.white.opacity(0.55)
    static let danger = Color(red: 0.91, green: 0.28, blue: 0.28)
}

struct VeilCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(VeilTheme.elevated)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.055), lineWidth: 1)
            )
    }
}

extension View {
    func veilCard() -> some View {
        modifier(VeilCardModifier())
    }
}
