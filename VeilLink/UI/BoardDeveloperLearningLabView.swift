import SwiftUI
import UniformTypeIdentifiers

/// Separate developer-only entrance for injecting reviewed board-learning
/// packages. Ordinary players can play, learn and export their own history, but
/// cannot import a package into the active repertoire from the public game UI.
struct BoardDeveloperLearningLabView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var controller: LocalAIGameController
    let game: MiniGameKind

    @State private var showsImporter = false
    @State private var message: String?
    @State private var preparingImport = false
    @State private var formationName = ""
    @State private var formationPurpose = ""
    @State private var formationObjective = ""

    private var gate: DeveloperLearningLabGate { model.developerLearningGate }

    /// Authorization is conjunctive and checked at each mutation boundary.
    private var authorizedSession: Bool {
        model.ownerMode.isAuthorized(for: .developerTraining)
            && !model.appLock.isLocked
            && gate.canImportTraining()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                if authorizedSession {
                    authorizedContent
                } else {
                    lockedContent
                }
            }
            .padding(16)
        }
        .background(VeilAmbientBackground())
        .navigationTitle("开发者学习室")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $showsImporter,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let selectedURL = urls.first else { return }
            guard authorizedSession else {
                message = "开发者会话已失效，请重新验证。"
                return
            }
            preparingImport = true
            Task {
                defer { preparingImport = false }
                do {
                    let file = try await VeilImportedFileAccess.materializeInBackground(
                        selectedURL,
                        acceptedExtensions: ["json"]
                    )
                    defer { VeilImportedFileAccess.removeStagedCopy(file) }
                    guard authorizedSession else {
                        gate.lock()
                        message = "Owner Mode 或应用锁状态已变化，请重新授权后导入。"
                        return
                    }
                    let report = try controller.importBoardLearning(from: file)
                    message = "已写入\(game.title)开发训练：\(report.completedGames) 局、\(report.rememberedPositions) 个局面。"
                    model.haptics.resolved()
                } catch {
                    message = error.localizedDescription
                }
            }
        }
        .alert("开发者学习室", isPresented: Binding(
            get: { message != nil },
            set: { if !$0 { message = nil } }
        )) {
            Button("好", role: .cancel) { message = nil }
        } message: {
            Text(message ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("\(game.title) · 私有训练入口", systemImage: "lock.shield")
                .font(.headline)
                .foregroundColor(VeilTheme.goldBright)
            Text("可审阅后导入训练包，也可从空棋盘录制私有阵法。普通对局仍会本地学习，但公开游戏页不提供训练包注入，避免外部文件污染个人棋谱。")
                .font(.caption)
                .foregroundColor(VeilTheme.secondaryText)
        }
        .veilCard(emphasized: true)
    }

    @ViewBuilder
    private var lockedContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("开发者模式未授权", systemImage: "lock.fill")
                .font(.subheadline.weight(.bold))
                .foregroundColor(VeilTheme.secondaryText)
            Text("请先在上帝模式的“开发者模式”中完成验证。训练包注入不会在普通游戏页提供密码输入或初始化入口。")
                .font(.caption)
                .foregroundColor(VeilTheme.secondaryText)
        }
        .veilCard()
    }

    private var authorizedContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("本地开发者会话有效", systemImage: "checkmark.shield")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(VeilTheme.success)
                Spacer()
                Button("锁定") { gate.lock() }
                    .font(.caption.weight(.semibold))
            }
            Text("训练包会先走系统“文件”选择器、安全作用域暂存与校验，再写入当前\(game.title)独立训练库。不会上传网络。")
                .font(.caption)
                .foregroundColor(VeilTheme.secondaryText)
            formationRecorder
            Button {
                guard authorizedSession else { gate.lock(); return }
                showsImporter = true
            } label: {
                Label(preparingImport ? "正在准备训练包…" : "导入开发训练包", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.borderedProminent)
            .disabled(preparingImport)
        }
        .veilCard()
    }

    private var formationRecorder: some View {
        VStack(alignment: .leading, spacing: 9) {
            Divider().background(VeilTheme.hairline)
            Text("阵法录制与教学")
                .font(.subheadline.weight(.bold))
            Text("开启录制会从空棋盘新开一条示范线；返回棋盘后可依次替双方落子来演示攻防，再回到这里为线路命名并解释用途。保存后，Bot 遇到相同前缀会优先采用你录制的电脑应手。")
                .font(.caption)
                .foregroundColor(VeilTheme.secondaryText)
            Toggle("录制模式：手动演示双方走子", isOn: Binding(
                get: { controller.developerTeachingMode },
                set: { controller.setDeveloperTeachingMode($0 && authorizedSession) }
            ))
            .font(.caption.weight(.semibold))
            TextField("阵法名称，例如：中心活三防守", text: $formationName)
                .textInputAutocapitalization(.never)
                .padding(10)
                .background(VeilTheme.subtleFillStrong, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            TextEditor(text: $formationPurpose)
                .frame(minHeight: 62)
                .padding(6)
                .background(VeilTheme.subtleFillStrong, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(alignment: .topLeading) {
                    if formationPurpose.isEmpty {
                        Text("阵法用途：它要防什么、制造什么威胁？")
                            .font(.caption)
                            .foregroundColor(VeilTheme.tertiaryText)
                            .padding(.horizontal, 11).padding(.vertical, 14)
                            .allowsHitTesting(false)
                    }
                }
            TextField("训练目的，例如：优先封堵对方冲四", text: $formationObjective)
                .padding(10)
                .background(VeilTheme.subtleFillStrong, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            Button("保存当前录制阵法") {
                guard authorizedSession else {
                    gate.lock()
                    message = "Owner Mode 或应用锁已失效，不能保存开发者阵法。"
                    return
                }
                do {
                    try controller.captureDeveloperFormation(
                        name: formationName,
                        purpose: formationPurpose,
                        objective: formationObjective
                    )
                    formationName = ""
                    formationPurpose = ""
                    formationObjective = ""
                    model.haptics.resolved()
                    message = "阵法已保存。后续同一局面前缀会将你录制的电脑应手作为高优先级训练。"
                } catch {
                    message = error.localizedDescription
                }
            }
            .buttonStyle(.bordered)
            Label("已保存 \(controller.developerFormationCount) 条私有阵法", systemImage: "point.3.connected.trianglepath.dotted")
                .font(.caption2)
                .foregroundColor(VeilTheme.goldBright)
        }
        .padding(.top, 2)
    }
}
