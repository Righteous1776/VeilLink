#if os(iOS) && canImport(SwiftUI)
import SwiftUI

/// A single quiet headline. Only overflowing text moves; no particle/danmaku
/// wall, sound, touch interception, or repeated VoiceOver announcements.
struct VeilopolyNewsTicker: View {
 let notice: VeilopolyBulletin
 @Environment(\.accessibilityReduceMotion) private var reduceMotion
 @Environment(\.scenePhase) private var scenePhase
 @State private var textWidth: CGFloat = 0
 @State private var began = Date()
 private let ink = Color(red: 0.10, green: 0.26, blue: 0.27)

 var body: some View {
  HStack(spacing: 7) {
   Image(systemName: notice.category == .market ? "chart.line.uptrend.xyaxis" : "newspaper")
    .font(.system(size: 12, weight: .semibold))
    .foregroundColor(Color(red: 0.70, green: 0.54, blue: 0.31))
   GeometryReader { geometry in
    TimelineView(.animation(minimumInterval: 1.0 / 30,
      paused: reduceMotion || scenePhase != .active || textWidth <= geometry.size.width)) { timeline in
     let elapsed = max(0, timeline.date.timeIntervalSince(began))
     let overflow = max(0, textWidth - geometry.size.width)
     let progress = min(1, max(0, (elapsed - 2) / 10))
     Text(notice.text)
      .font(.system(size: 12, weight: .medium))
      .foregroundColor(ink)
      .fixedSize(horizontal: true, vertical: false)
      .background(GeometryReader { measured in
       Color.clear.preference(key: BulletinTextWidth.self, value: measured.size.width)
      })
      .offset(x: reduceMotion ? 0 : -overflow * CGFloat(progress))
      .frame(height: geometry.size.height, alignment: .leading)
    }
   }
   .clipped()
  }
  .padding(.horizontal, 9)
  .frame(height: 34)
  .background(Color(red: 0.96, green: 0.93, blue: 0.86).opacity(0.96), in: RoundedRectangle(cornerRadius: 8))
  .overlay { RoundedRectangle(cornerRadius: 8).stroke(ink.opacity(0.18), lineWidth: 0.7) }
  .onPreferenceChange(BulletinTextWidth.self) { textWidth = $0 }
  .onAppear { began = Date() }
  .onChange(of: scenePhase) { phase in
   if phase == .active { began = Date() }
  }
  .accessibilityElement(children: .ignore)
  .accessibilityLabel("城市快讯：" + notice.text)
  .allowsHitTesting(false)
 }
}

private struct BulletinTextWidth: PreferenceKey {
 static var defaultValue: CGFloat = 0
 static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}
#endif
