import SwiftUI

struct RealtimeGameGuideStep: Identifiable {
    let id: Int
    let icon: String
    let title: String
    let detail: String
}

struct RealtimeGameGuideView: View {
    let title: String
    let subtitle: String
    let steps: [RealtimeGameGuideStep]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(title).font(.largeTitle.bold()).foregroundColor(VeilTheme.text)
                        Text(subtitle).font(.subheadline).foregroundColor(VeilTheme.secondaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(steps) { step in
                        HStack(alignment: .top, spacing: 13) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(VeilTheme.gold.opacity(0.13))
                                Image(systemName: step.icon)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(VeilTheme.goldBright)
                            }
                            .frame(width: 46, height: 46)
                            VStack(alignment: .leading, spacing: 5) {
                                Text("\(step.id). \(step.title)").font(.headline).foregroundColor(VeilTheme.text)
                                Text(step.detail).font(.subheadline).foregroundColor(VeilTheme.secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(14)
                        .background(VeilTheme.elevated.opacity(0.88), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(VeilTheme.hairline, lineWidth: 1))
                    }

                    Label("所有运算都在本机实时完成；离开页面会暂停渲染。低电量或旧设备会自动降低粒子与后处理，但不会改变玩法规则。", systemImage: "cpu")
                        .font(.caption).foregroundColor(VeilTheme.secondaryText)
                        .padding(14).veilCard()
                }
                .padding(18)
            }
            .background(VeilAmbientBackground())
            .navigationTitle("新手教程")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("开始") { dismiss() }
                }
            }
        }
    }
}
