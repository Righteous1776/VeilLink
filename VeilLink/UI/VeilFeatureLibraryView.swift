import SwiftUI

struct VeilFeatureLibraryView: View {
    let registry: VeilFeatureRegistry
    let profile: VeilFeatureRuntimeProfile
    let passedGates: VeilFeatureGate
    let onOpen: (String) -> Void

    @State private var query = ""
    @State private var domain: VeilFeatureDomain?
    @State private var offset = 0

    private let pageSize = 30

    private var page: VeilFeatureQueryPage {
        registry.query(VeilFeatureQuery(text: query, domain: domain, offset: offset, limit: pageSize))
    }

    var body: some View {
        VeilStableScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                search
                domainFilter
                resultSummary

                LazyVStack(spacing: 10) {
                    ForEach(page.items) { feature in
                        featureRow(feature)
                    }
                }

                if page.totalCount == 0 {
                    Text("没有匹配的功能")
                        .font(.callout)
                        .foregroundColor(VeilTheme.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                } else {
                    pagination
                }
            }
        }
        .padding(.horizontal, 14)
        .background(VeilAmbientBackground())
        .navigationTitle("功能库")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: query) { _ in offset = 0 }
        .onChange(of: domain) { _ in offset = 0 }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("FEATURE LIBRARY")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(1.3)
                .foregroundColor(VeilTheme.mutedGold)
            Text("一个入口，按需加载")
                .font(.title2.bold())
                .foregroundColor(VeilTheme.text)
            Text("这里只渲染当前 30 项；不可用功能会说明缺少的验证或权限。")
                .font(.caption)
                .foregroundColor(VeilTheme.secondaryText)
        }
    }

    private var search: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass").foregroundColor(VeilTheme.tertiaryText)
            TextField("搜索名称、功能包、关键词或 ID", text: $query)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(VeilTheme.tertiaryText)
                }
                .accessibilityLabel("清空搜索")
            }
        }
        .padding(.horizontal, 13)
        .frame(height: 44)
        .veilCompactToolSurface(cornerRadius: 14)
    }

    private var domainFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterButton(title: "全部", value: nil)
                ForEach(VeilFeatureDomain.allCases) { value in
                    filterButton(title: value.title, value: value)
                }
            }
        }
    }

    private func filterButton(title: String, value: VeilFeatureDomain?) -> some View {
        Button { domain = value } label: {
            Text(title)
                .font(.caption.bold())
                .foregroundColor(domain == value ? VeilTheme.panel : VeilTheme.secondaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(domain == value ? VeilTheme.gold : VeilTheme.panelSoft)
                .clipShape(Capsule())
        }
        .buttonStyle(VeilPressStyle())
    }

    private var resultSummary: some View {
        HStack {
            Text("共 \(page.totalCount) 项")
            Spacer()
            if page.totalCount > 0 {
                Text("\(page.offset + 1)–\(min(page.offset + page.items.count, page.totalCount))")
            }
        }
        .font(.caption.monospacedDigit())
        .foregroundColor(VeilTheme.tertiaryText)
    }

    private func featureRow(_ feature: VeilFeatureDescriptor) -> some View {
        let decision = registry.launchDecision(for: feature.id, profile: profile, passedGates: passedGates)
        return Button {
            if decision.canLaunch { onOpen(feature.id) }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon(feature.domain))
                    .font(.title3)
                    .foregroundColor(decision.canLaunch ? VeilTheme.gold : VeilTheme.tertiaryText)
                    .frame(width: 38, height: 38)
                    .background(VeilTheme.panelSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(feature.title).font(.subheadline.bold()).foregroundColor(VeilTheme.text)
                        Spacer(minLength: 4)
                        Text(statusTitle(decision.state))
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(statusColor(decision.state))
                    }
                    Text(feature.subtitle).font(.caption).foregroundColor(VeilTheme.secondaryText).lineLimit(2)
                    if let reason = decision.reason {
                        Text(reason).font(.caption2).foregroundColor(VeilTheme.tertiaryText).lineLimit(2)
                    }
                }
                Image(systemName: decision.canLaunch ? "chevron.right" : "lock.fill")
                    .font(.caption.bold())
                    .foregroundColor(VeilTheme.tertiaryText)
                    .padding(.top, 3)
            }
            .padding(13)
            .veilCompactToolSurface(cornerRadius: 15)
        }
        .buttonStyle(VeilPressStyle())
        .accessibilityHint(decision.canLaunch ? "打开功能" : (decision.reason ?? "当前不可用"))
    }

    private var pagination: some View {
        HStack(spacing: 10) {
            Button("上一页") { offset = max(0, offset - pageSize) }
                .disabled(offset == 0)
            Spacer()
            Button("下一页") { offset += pageSize }
                .disabled(!page.hasMore)
        }
        .font(.subheadline.bold())
        .foregroundColor(VeilTheme.gold)
        .padding(.vertical, 8)
    }

    private func icon(_ domain: VeilFeatureDomain) -> String {
        switch domain {
        case .communication: return "bubble.left.and.bubble.right.fill"
        case .productivity: return "checkmark.circle.fill"
        case .diagnostics: return "waveform.path.ecg"
        case .entertainment: return "sparkles"
        case .emotion: return "heart.fill"
        case .games: return "gamecontroller.fill"
        case .utilities: return "wrench.and.screwdriver.fill"
        case .experimental: return "flask.fill"
        }
    }

    private func statusTitle(_ state: VeilFeatureLaunchState) -> String {
        switch state {
        case .available: return "READY"
        case .degraded: return "ADAPT"
        case .blocked: return "GATED"
        case .thermallyDeferred: return "COOL"
        }
    }

    private func statusColor(_ state: VeilFeatureLaunchState) -> Color {
        switch state {
        case .available: return .green
        case .degraded: return .orange
        case .blocked, .thermallyDeferred: return VeilTheme.tertiaryText
        }
    }
}
