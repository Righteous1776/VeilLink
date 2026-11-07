#if os(iOS) && canImport(SwiftUI)
import SwiftUI
import VeilopolyEngine

/// One visual language for all live Veilopoly paper documents.
/// This embeds *inside* existing Astra controls, not over the board or buttons.
struct VeilopolyCivicDocumentPanel: View {
 let document: VeilopolyCivicDocument
 @AppStorage("veilopoly.dayFelt.v1") private var dayFelt = false
 private var ink: Color {
  dayFelt ? Color(red: 0.11, green: 0.28, blue: 0.29)
          : Color(red: 0.91, green: 0.95, blue: 0.92)
 }
 private var bronze: Color {
  dayFelt ? Color(red: 0.69, green: 0.52, blue: 0.29)
          : Color(red: 0.81, green: 0.67, blue: 0.46)
 }
 private var panelColor: Color {
  dayFelt ? Color(red: 0.968, green: 0.94, blue: 0.872)
          : Color(red: 0.07, green: 0.15, blue: 0.18)
 }

 var body: some View {
  VStack(alignment: .leading, spacing: 7) {
   HStack(alignment: .firstTextBaseline, spacing: 7) {
    Image(systemName: "doc.text")
     .font(.system(size: 13, weight: .medium))
     .accessibilityHidden(true)
    Text(document.title)
     .font(.system(size: 15, weight: .semibold, design: .serif))
     .fixedSize(horizontal: false, vertical: true)
    Spacer(minLength: 0)
   }
   .foregroundColor(ink)
   Text(document.subtitle)
    .font(.system(size: 13, weight: .medium, design: .serif))
    .foregroundColor(bronze)
    .fixedSize(horizontal: false, vertical: true)
   Rectangle()
    .fill(bronze.opacity(0.55))
    .frame(height: 1)
    .accessibilityHidden(true)
   ForEach(document.fields.indices, id: \.self) { index in
    let field = document.fields[index]
    HStack(alignment: .top, spacing: 8) {
     Text(field.label)
      .foregroundColor(ink.opacity(0.7))
      .frame(minWidth: 54, alignment: .leading)
      .fixedSize(horizontal: false, vertical: true)
     Spacer(minLength: 2)
     Text(field.value)
      .fontWeight(.medium)
      .foregroundColor(ink)
      .multilineTextAlignment(.trailing)
      .fixedSize(horizontal: false, vertical: true)
    }
    .font(.system(size: 14))
   }
   Text(document.note)
    .font(.system(size: 13))
    .foregroundColor(ink.opacity(0.7))
    .fixedSize(horizontal: false, vertical: true)
    .padding(.top, 2)
  }
  .padding(13)
  .frame(maxWidth: .infinity, alignment: .leading)
  .background(panelColor, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
  .overlay {
   RoundedRectangle(cornerRadius: 10, style: .continuous)
    .strokeBorder(bronze.opacity(0.85), lineWidth: 1)
    .allowsHitTesting(false)
  }
  .accessibilityElement(children: .contain)
  .accessibilityLabel(document.title)
 }
}
#endif
