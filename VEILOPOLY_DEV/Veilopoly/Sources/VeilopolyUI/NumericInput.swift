#if os(iOS) && canImport(SwiftUI)
import SwiftUI

/// Button-backed numeric field: never summons the system keyboard over the
/// landscape decision panel. Confirm changes a draft field, never executes it.
struct VeilopolyNumericInput: View {
 let title: String
 @Binding var text: String
 var bounds: ClosedRange<Int> = 0...1_000_000_000
 var showsTitle = true
 @State private var editing = false
 @Environment(\.veilopolyInterfaceTheme) private var interfaceTheme

 init(title: String, text: Binding<String>, bounds: ClosedRange<Int> = 0...1_000_000_000,
      showsTitle: Bool = true) {
  self.title = title
  _text = text
  self.bounds = bounds
  self.showsTitle = showsTitle
 }

 var body: some View {
  Button { editing = true } label: {
   VStack(alignment: .leading, spacing: 2) {
    if showsTitle { Text(title).font(.caption2).foregroundColor(.secondary) }
    Text(text.isEmpty ? "点击输入" : text)
     .font(.system(size: 15, weight: .semibold, design: .monospaced))
     .lineLimit(1).minimumScaleFactor(0.75)
   }
   .frame(minWidth: 44, maxWidth: .infinity, minHeight: 44, alignment: showsTitle ? .leading : .center)
   .contentShape(Rectangle())
  }
  .buttonStyle(.plain)
  .accessibilityLabel(title)
  .accessibilityValue(text.isEmpty ? "未填写" : text)
  .accessibilityHint("打开数字面板；确认仅填写数值，不提交游戏操作")
  .sheet(isPresented: $editing) {
   VeilopolyNumberPad(title: title, initialText: text, bounds: bounds) { text = $0 }
    .environment(\.colorScheme, interfaceTheme.colorScheme)
    .preferredColorScheme(interfaceTheme.colorScheme)
  }
 }
}

private struct VeilopolyNumberPad: View {
 let title: String
 let onConfirm: (String) -> Void
 @State private var draft: VeilopolyNumericInputDraft
 @State private var inputMessage: String?
 @Environment(\.dismiss) private var dismiss
 private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

 init(title: String, initialText: String, bounds: ClosedRange<Int>,
      onConfirm: @escaping (String) -> Void) {
  self.title = title
  self.onConfirm = onConfirm
  _draft = State(initialValue: VeilopolyNumericInputDraft(text: initialText, bounds: bounds))
 }

 var body: some View {
  GeometryReader { geometry in
   // Also scrolls on very short windows / large Dynamic Type. No text field
   // means there is no keyboard to cover Confirm or Cancel.
   ScrollView {
    VStack(alignment: .leading, spacing: 10) {
     HStack {
      Text(title).font(.headline)
      Spacer()
      Button { dismiss() } label: {
       Text("取消").frame(minWidth: 64, minHeight: 44).contentShape(Rectangle())
      }
     }
     if geometry.size.width > geometry.size.height {
      HStack(alignment: .top, spacing: 16) {
       editorSummary.frame(maxWidth: .infinity)
       keypad.frame(maxWidth: .infinity)
      }
     } else {
      editorSummary
      keypad
     }
    }
    .padding(12)
   }
   .background(Color(uiColor: .systemBackground).ignoresSafeArea())
   .foregroundColor(.primary)
  }
 }

 private var editorSummary: some View {
  VStack(alignment: .leading, spacing: 8) {
   Text(draft.text.isEmpty ? "未填写" : draft.text)
    .font(.system(size: 28, weight: .semibold, design: .monospaced))
    .lineLimit(1).minimumScaleFactor(0.5)
    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
    .accessibilityLabel("当前输入")
    .accessibilityValue(draft.text.isEmpty ? "未填写" : draft.text)
   Text("输入范围：\(draft.bounds.lowerBound)…\(draft.bounds.upperBound)")
    .font(.caption).foregroundColor(.secondary)
   Text(inputMessage ?? (draft.value == nil ? "请输入范围内的整数" : "确认仅填写数值，不会下单或扣款"))
    .font(.caption).foregroundColor(draft.value == nil || inputMessage != nil ? .orange : .secondary)
    .fixedSize(horizontal: false, vertical: true)
   Button {
    guard let value = draft.value else { return }
    onConfirm(String(value))
    dismiss()
   } label: {
    Text("确认填写").frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())
   }
   .buttonStyle(.borderedProminent)
   .disabled(draft.value == nil)
  }
 }

 private var keypad: some View {
  LazyVGrid(columns: columns, spacing: 8) {
   ForEach(1...9, id: \.self) { digit in digitButton(digit) }
   key("清空") { draft.clear(); inputMessage = nil }
   digitButton(0)
   key("退格") { draft.backspace(); inputMessage = nil }
  }
 }

 private func digitButton(_ digit: Int) -> some View {
  key(String(digit)) { inputMessage = draft.append(digit) ? nil : "已达输入上限，请退格或清空" }
 }

 private func key(_ label: String, action: @escaping () -> Void) -> some View {
  Button(action: action) {
   Text(label).font(.headline).frame(minWidth: 44, maxWidth: .infinity, minHeight: 44)
    .contentShape(Rectangle())
  }
  .buttonStyle(.bordered)
 }
}
#endif
