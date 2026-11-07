#if os(iOS) && canImport(SwiftUI)
import SwiftUI

/// A compact 3-row numeric pad designed for iPhone landscape.
/// No native system keyboard; keeps the editable value and Done action visible.
struct VeilopolyNumberPad: View {
 let title: String
 @Binding var value: String
 let onDone: () -> Void

 private let digits = ["1", "2", "3", "清空",
                       "4", "5", "6", "删除",
                       "7", "8", "9", "0"]

 var body: some View {
  ZStack {
   Color.black.opacity(0.78)
    .ignoresSafeArea()
    .onTapGesture(perform: onDone)

   VStack(spacing: 8) {
    HStack(spacing: 12) {
     Text(title)
      .font(.system(size: 16, weight: .semibold))
      .lineLimit(1)
     Spacer(minLength: 8)
     Text(value.isEmpty ? "0" : value)
      .font(.system(size: 24, weight: .bold, design: .monospaced))
      .minimumScaleFactor(0.75)
      .lineLimit(1)
      .accessibilityLabel("\(title)：\(value)")
    }
    .frame(minHeight: 40)

    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7),
                             count: 4), spacing: 7) {
     ForEach(digits, id: \.self) { digit in
      Button { apply(digit) } label: {
       Text(digit)
        .font(.system(size: digit.count > 1 ? 15 : 21, weight: .semibold))
        .frame(maxWidth: .infinity, minHeight: 46)
        .background(.white.opacity(0.13),
                    in: RoundedRectangle(cornerRadius: 9))
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(digit)
     }
    }
    Button(action: onDone) {
     Label("完成", systemImage: "checkmark")
      .font(.system(size: 17, weight: .semibold))
      .frame(maxWidth: .infinity, minHeight: 46)
      .background(Color(red: 0.62, green: 0.47, blue: 0.27),
                  in: RoundedRectangle(cornerRadius: 9))
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
   }
   .foregroundColor(.white)
   .padding(12)
   .frame(maxWidth: 448)
   .background(Color(red: 0.08, green: 0.16, blue: 0.19),
               in: RoundedRectangle(cornerRadius: 16))
   .overlay {
    RoundedRectangle(cornerRadius: 16)
     .strokeBorder(Color(red: 0.72, green: 0.58, blue: 0.38), lineWidth: 1)
     .allowsHitTesting(false)
   }
   .padding(.horizontal, 12)
  }
  .frame(maxWidth: .infinity, maxHeight: .infinity)
  .preferredColorScheme(.dark)
  .accessibilityElement(children: .contain)
 }

 private func apply(_ digit: String) {
  switch digit {
  case "清空": value = ""
  case "删除":
   if !value.isEmpty { value.removeLast() }
  default:
   guard value.count < 9 else { return }
   value = value == "0" ? digit : value + digit
  }
 }
}
#endif
