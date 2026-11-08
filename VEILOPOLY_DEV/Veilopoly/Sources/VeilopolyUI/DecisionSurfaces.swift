#if os(iOS) && canImport(SwiftUI)
import SwiftUI

private struct DecisionContentWidthKey: EnvironmentKey {
 static let defaultValue = 256.0
}
extension EnvironmentValues {
 var veilopolyDecisionContentWidth: Double {
  get { self[DecisionContentWidthKey.self] }
  set { self[DecisionContentWidthKey.self] = newValue }
 }
}

/// No GeometryReader height feedback: the grid measures its real wrapped
/// buttons. Large accessibility text deliberately uses a single column.
struct VeilopolyDecisionActions<Content: View>: View {
 @Environment(\.veilopolyDecisionContentWidth) private var width
 @Environment(\.dynamicTypeSize) private var textSize
 private let content: Content
 init(@ViewBuilder content: () -> Content) { self.content = content() }
 var body: some View {
  let count = VeilopolyDecisionLayout.columns(contentWidth: width,
                                             accessibilityText: textSize.isAccessibilitySize)
  LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8, alignment: .top), count: count),
            alignment: .leading, spacing: 8) { content }
 }
}

struct VeilopolyDecisionHeading: View {
 let title: String
 let subtitle: String
 let symbol: String
 var body: some View {
  HStack(alignment: .top, spacing: 9) {
   Image(systemName: symbol)
    .font(.system(size: 17, weight: .medium))
    .foregroundColor(Color(red: 0.86, green: 0.73, blue: 0.48))
    .frame(width: 28, height: 28)
    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 7))
    .accessibilityHidden(true)
   VStack(alignment: .leading, spacing: 3) {
    Text(title).font(.headline)
    Text(subtitle).font(.caption).foregroundStyle(.secondary)
   }
   .fixedSize(horizontal: false, vertical: true)
  }
  .frame(maxWidth: .infinity, alignment: .leading)
  .accessibilityElement(children: .combine)
 }
}

struct VeilopolyDecisionMetric: View {
 let title: String
 let value: String
 var emphasized = false
 @Environment(\.dynamicTypeSize) private var textSize
 var body: some View {
  Group {
   if textSize.isAccessibilitySize {
    VStack(alignment: .leading, spacing: 3) { caption; amount }
   } else {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
     caption
     Spacer(minLength: 4)
     amount.multilineTextAlignment(.trailing)
    }
   }
  }
  .frame(maxWidth: .infinity, alignment: .leading)
  .accessibilityElement(children: .combine)
 }
 private var caption: some View {
  Text(title).font(.caption).foregroundStyle(.secondary)
   .fixedSize(horizontal: false, vertical: true)
 }
 private var amount: some View {
  Text(value).font(emphasized ? .headline : .subheadline).monospacedDigit()
   .foregroundColor(emphasized ? Color(red: 0.97, green: 0.84, blue: 0.59) : .white)
   .fixedSize(horizontal: false, vertical: true)
 }
}

struct VeilopolyTradeTransferCard: View {
 let title: String
 let symbol: String
 let transfer: VeilopolyTransferReview
 var body: some View {
  VStack(alignment: .leading, spacing: 6) {
   Label(title, systemImage: symbol).font(.subheadline.weight(.semibold))
   VeilopolyDecisionMetric(title: "现金", value: "¥\(transfer.cash)")
   Text("地产：" + (transfer.properties.isEmpty ? "无" : transfer.properties.joined(separator: "、")))
    .font(.caption).fixedSize(horizontal: false, vertical: true)
   Text("出狱卡：机会 \(transfer.chanceCards) · 命运 \(transfer.chestCards)")
    .font(.caption).foregroundStyle(.secondary)
    .fixedSize(horizontal: false, vertical: true)
  }
  .padding(9)
  .frame(maxWidth: .infinity, alignment: .leading)
  .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
  .accessibilityElement(children: .combine)
 }
}
#endif
