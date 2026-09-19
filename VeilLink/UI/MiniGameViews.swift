import SwiftUI
import Combine
import Foundation

struct MiniGameHubView: View {
    @ObservedObject var model: AppModel
    let conversation: ConversationSummary

    @Environment(\.dismiss) private var dismiss
    @State private var messages: [ChatMessage] = []
    @State private var sessions: [MiniGameSessionSnapshot] = []
    @State private var selectedSessionID: String?
    @State private var creatingGame: MiniGameKind?
    @State private var reloadGeneration = 0

    init(model: AppModel, conversation: ConversationSummary, initialSessionID: String? = nil) {
        self.model = model
        self.conversation = conversation
        _selectedSessionID = State(initialValue: initialSessionID)
    }

    private var liveSessions: [MiniGameSessionSnapshot] {
        sessions.filter {
            switch $0.status {
            case .invited, .active: return true
            case .declined, .cancelled, .finished: return false
            }
        }
    }

    private var incomingInvitations: [MiniGameSessionSnapshot] {
        liveSessions.filter { $0.status == .invited && !$0.hostIsLocal }
    }

    private var otherLiveSessions: [MiniGameSessionSnapshot] {
        liveSessions.filter { !($0.status == .invited && !$0.hostIsLocal) }
    }

    private var historySessions: [MiniGameSessionSnapshot] {
        sessions.filter {
            switch $0.status {
            case .invited, .active: return false
            case .declined, .cancelled, .finished: return true
            }
        }
    }

    private var statistics: MiniGameStatistics { MiniGameStatistics(sessions: sessions) }

    private func liveSession(for game: MiniGameKind) -> MiniGameSessionSnapshot? {
        liveSessions.first { $0.game == game }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    if statistics.completed > 0 { statisticsOverview }
                    gamePicker

                    if !incomingInvitations.isEmpty {
                        sessionSection(title: "待回应", sessions: incomingInvitations)
                    }
                    if !otherLiveSessions.isEmpty {
                        sessionSection(title: "进行中", sessions: otherLiveSessions)
                    }
                    if !historySessions.isEmpty {
                        sessionSection(title: "最近对局", sessions: Array(historySessions.prefix(8)))
                    }
                    if sessions.isEmpty {
                        emptyState
                    }
                }
                .padding(16)
            }
            .background(VeilAmbientBackground().ignoresSafeArea())
            .navigationTitle("双人小游戏")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                        .foregroundColor(VeilTheme.gold)
                }
            }
        }
        .navigationViewStyle(.stack)
        .onAppear(perform: reload)
        .onChange(of: model.messagesRevision) { _ in reload() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 9) {
                Image(systemName: "lock.shield.fill")
                    .foregroundColor(VeilTheme.gold)
                Text("加密小游戏")
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .foregroundColor(VeilTheme.text)
            }
            Text("棋局操作沿用当前聊天的端到端加密、ACK 与断线重发；重新打开 App 后也能从加密历史恢复棋盘。")
                .font(.subheadline)
                .foregroundColor(VeilTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            MiniGameLinkStatusView(
                bluetooth: model.bluetooth,
                sessions: model.sessions,
                peerIdentityID: conversation.peerIdentityID
            )
        }
        .padding(.bottom, 2)
    }

    private var statisticsOverview: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                sectionTitle("战绩")
                Spacer()
                Text("仅基于当前加密会话")
                    .font(.caption2)
                    .foregroundColor(VeilTheme.tertiaryText)
            }

            HStack(spacing: 9) {
                statisticTile(value: "\(statistics.completed)", label: "已完成")
                statisticTile(value: "\(statistics.wins)", label: "胜")
                statisticTile(value: "\(statistics.losses)", label: "负")
                statisticTile(value: "\(statistics.draws)", label: "和")
            }

            HStack(spacing: 8) {
                Label("胜率 \(Int((statistics.winRate * 100).rounded()))%", systemImage: "chart.line.uptrend.xyaxis")
                if statistics.currentWinStreak > 1 {
                    Text("·")
                    Label("\(statistics.currentWinStreak) 连胜", systemImage: "flame.fill")
                }
                Spacer()
            }
            .font(.caption.weight(.semibold))
            .foregroundColor(VeilTheme.gold)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(MiniGameKind.allCases) { game in
                        if let record = statistics.byGame[game], record.completed > 0 {
                            HStack(spacing: 5) {
                                Image(systemName: game.icon)
                                Text(game.title)
                                Text("\(record.wins)-\(record.losses)-\(record.draws)")
                                    .monospacedDigit()
                                    .foregroundColor(VeilTheme.gold)
                            }
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(VeilTheme.secondaryText)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.045))
                            .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }

    private func statisticTile(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundColor(VeilTheme.text)
            Text(label)
                .font(.caption2)
                .foregroundColor(VeilTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(VeilTheme.elevated.opacity(0.74))
        .clipShape(VeilPanelShape(cut: 8, radius: 6))
        .overlay(VeilPanelShape(cut: 8, radius: 6).stroke(VeilTheme.hairline, lineWidth: 1))
    }

    private var gamePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("开始一局")
            ForEach(MiniGameKind.allCases) { game in
                let existing = liveSession(for: game)
                Button {
                    if let existing { selectedSessionID = existing.id }
                    else { createGame(game) }
                } label: {
                    HStack(spacing: 13) {
                        ZStack {
                            Circle().fill(VeilTheme.gold.opacity(0.09))
                            Image(systemName: game.icon)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(VeilTheme.gold)
                        }
                        .frame(width: 42, height: 42)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(game.title)
                                .font(.headline)
                                .foregroundColor(VeilTheme.text)
                            Text(game.subtitle)
                                .font(.caption)
                                .foregroundColor(VeilTheme.secondaryText)
                                .lineLimit(2)
                        }
                        Spacer(minLength: 8)
                        if creatingGame == game {
                            ProgressView().tint(VeilTheme.gold)
                        } else if existing != nil {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("继续")
                                    .font(.caption2.weight(.bold))
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.title3)
                            }
                            .foregroundColor(VeilTheme.gold)
                        } else {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundColor(VeilTheme.gold)
                        }
                    }
                    .padding(14)
                    .background(VeilTheme.elevated.opacity(0.88))
                    .clipShape(VeilPanelShape(cut: 13, radius: 7))
                    .overlay(VeilPanelShape(cut: 13, radius: 7).stroke(VeilTheme.hairline, lineWidth: 1))
                }
                .buttonStyle(VeilPressStyle())
                .disabled(creatingGame != nil)
                .accessibilityLabel(existing == nil ? "开始\(game.title)，\(game.subtitle)" : "继续\(game.title)对局")
            }
        }
    }

    @ViewBuilder
    private func sessionSection(title: String, sessions: [MiniGameSessionSnapshot]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(title)
            ForEach(sessions) { session in
                NavigationLink(
                    destination: MiniGameSessionView(model: model, conversation: conversation, sessionID: session.id),
                    tag: session.id,
                    selection: $selectedSessionID
                ) {
                    MiniGameSessionRow(session: session)
                }
                .buttonStyle(VeilPressStyle())
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundColor(VeilTheme.mutedGold)
            .textCase(.uppercase)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "gamecontroller")
                .font(.system(size: 34, weight: .light))
                .foregroundColor(VeilTheme.secondaryText)
            Text("还没有对局")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(VeilTheme.text)
            Text("选择上面的游戏，对方接受后即可开始。")
                .font(.caption)
                .foregroundColor(VeilTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private func createGame(_ game: MiniGameKind) {
        guard creatingGame == nil else { return }
        creatingGame = game
        let packet = MiniGamePacket(game: game, command: .invite)
        do {
            try model.sessions.sendMiniGamePacket(packet, to: conversation.peerIdentityID)
            model.haptics.impact()
            reload()
            selectedSessionID = packet.sessionID
        } catch {
            model.alertMessage = error.localizedDescription
            model.haptics.error()
        }
        creatingGame = nil
    }

    private func reload() {
        reloadGeneration &+= 1
        let generation = reloadGeneration
        let loaded = model.database.fetchMessages(conversationID: conversation.id)
        let loadedSessions = MiniGameSessionBuilder.sessions(from: loaded)
        guard generation == reloadGeneration else { return }
        messages = loaded
        sessions = loadedSessions
    }
}

private struct MiniGameLinkStatusView: View {
    @ObservedObject var bluetooth: BLETransport
    @ObservedObject var sessions: SessionCoordinator
    let peerIdentityID: String
    var latestGameMessage: ChatMessage? = nil

    private var transportID: UUID? { sessions.transportID(for: peerIdentityID) }
    private var snapshot: BLEPeerLinkSnapshot? {
        guard let transportID else { return nil }
        return bluetooth.linkSnapshots[transportID] ?? bluetooth.linkSnapshot(for: transportID)
    }
    private var secureReady: Bool { sessions.hasSecureSession(for: peerIdentityID) }
    private var linkReady: Bool { snapshot?.isConnected == true && secureReady }

    private var primaryText: String {
        if linkReady { return "对手链路已就绪" }
        if snapshot?.isConnected == true { return "蓝牙已连接 · 安全会话恢复中" }
        if snapshot?.isRecovering == true { return "正在自动恢复对手链路" }
        if transportID != nil { return "对手暂时离线" }
        return "等待发现对手设备"
    }

    private var detailText: String? {
        guard let snapshot else { return nil }
        if linkReady { return snapshot.compactDetail }
        if snapshot.pendingPackets > 0 { return "操作会保留在加密待发送队列 · \(snapshot.queueSummary)" }
        return snapshot.rssi.map { "\($0) dBm · \(snapshot.qualityTitle)" }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: linkReady ? "antenna.radiowaves.left.and.right" : (snapshot?.isRecovering == true ? "arrow.triangle.2.circlepath" : "dot.radiowaves.left.and.right"))
                .font(.caption.weight(.bold))
                .foregroundColor(linkReady ? VeilTheme.success : VeilTheme.gold)

            VStack(alignment: .leading, spacing: 2) {
                Text(primaryText)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(linkReady ? VeilTheme.text : VeilTheme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                if let detailText {
                    Text(detailText)
                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                        .foregroundColor(VeilTheme.tertiaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
            }

            Spacer(minLength: 4)

            if let latestGameMessage {
                MiniGameDeliveryBadge(state: latestGameMessage.deliveryState)
            } else if let snapshot, linkReady {
                Text("H\(snapshot.healthScore)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(VeilTheme.gold)
                    .accessibilityLabel("链路健康度 \(snapshot.healthScore)")
            }

            if !linkReady, let transportID {
                Button {
                    if snapshot?.isConnected == true {
                        sessions.recoverSecureSession(for: peerIdentityID)
                        bluetooth.refreshLinks()
                    } else {
                        bluetooth.recover(transportID)
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption.weight(.bold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .foregroundColor(VeilTheme.gold)
                .accessibilityLabel("立即恢复对手蓝牙链路")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.035))
        .clipShape(VeilPanelShape(cut: 8, radius: 6))
        .overlay(VeilPanelShape(cut: 8, radius: 6).stroke(VeilTheme.hairline, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

private struct MiniGameDeliveryBadge: View {
    let state: ChatMessage.DeliveryState

    private var label: String {
        switch state {
        case .queued: return "已排队"
        case .sending: return "发送中"
        case .paused: return "待恢复"
        case .delivered: return "已送达"
        case .cancelled: return "已取消"
        case .failed: return "失败"
        }
    }

    private var icon: String {
        switch state {
        case .queued: return "clock"
        case .sending: return "arrow.up.circle"
        case .paused: return "pause.circle"
        case .delivered: return "checkmark.circle.fill"
        case .cancelled: return "minus.circle"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
            Text(label)
        }
        .font(.system(size: 9.5, weight: .semibold))
        .foregroundColor(state == .failed ? VeilTheme.danger : (state == .delivered ? VeilTheme.success : VeilTheme.gold))
        .lineLimit(1)
    }
}

private struct MiniGameSessionRow: View {
    let session: MiniGameSessionSnapshot

    private var needsAttention: Bool { session.status == .invited && !session.hostIsLocal }

    private var status: String {
        switch session.status {
        case .invited: return session.hostIsLocal ? "等待对方接受" : "邀请你加入"
        case .active: return session.isLocalTurn ? "轮到你" : "等待对方"
        case .declined: return "已拒绝"
        case .cancelled: return "已取消"
        case .finished(let winner):
            guard let winner else {
                return session.xiangqi?.drawReason == .threefoldRepetition ? "三次重复 · 和棋" : "和棋"
            }
            return winner == session.localPlayer ? "你赢了" : "对方获胜"
        }
    }

    private var activityText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: session.lastActivity, relativeTo: Date())
    }

    var body: some View {
        HStack(spacing: 13) {
            ZStack {
                Circle().fill(session.isLocalTurn ? VeilTheme.gold.opacity(0.13) : VeilTheme.gold.opacity(0.07))
                Image(systemName: session.game.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(session.isLocalTurn ? VeilTheme.gold : VeilTheme.secondaryText)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text(session.game.title)
                        .font(.headline)
                        .foregroundColor(VeilTheme.text)
                    if needsAttention {
                        Text("待回应")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Color.black.opacity(0.85))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(VeilTheme.gold)
                            .clipShape(Capsule())
                    } else if session.isLocalTurn {
                        Text("你的回合")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Color.black.opacity(0.85))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(VeilTheme.gold)
                            .clipShape(Capsule())
                    }
                }
                Text("\(status) · " + (session.game == .tactical ? "\(session.moveCount) 道命令" : "\(session.moveCount) 手") + " · \(activityText)")
                    .font(.caption)
                    .foregroundColor(session.isLocalTurn ? VeilTheme.gold : VeilTheme.secondaryText)
                    .lineLimit(1)
            }
            Spacer()
            Text("#\(session.id.prefix(4))")
                .font(.caption2.monospaced())
                .foregroundColor(VeilTheme.tertiaryText)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundColor(VeilTheme.tertiaryText)
        }
        .padding(14)
        .background(VeilTheme.elevated.opacity(0.86))
        .clipShape(VeilPanelShape(cut: 12, radius: 7))
        .overlay(VeilPanelShape(cut: 12, radius: 7).stroke(needsAttention ? VeilTheme.gold.opacity(0.55) : VeilTheme.hairline, lineWidth: needsAttention ? 1.4 : 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(session.game.title)，\(status)，已进行 \(session.moveCount) " + (session.game == .tactical ? "道命令" : "手"))
    }
}

struct MiniGameConversationCard: View {
    let session: MiniGameSessionSnapshot
    let onOpen: () -> Void

    private var statusText: String {
        switch session.status {
        case .invited: return session.hostIsLocal ? "已邀请对方 · 等待接受" : "邀请你加入 · 点击回应"
        case .active:
            if session.game == .xiangqi, let state = session.xiangqi, state.isCurrentPlayerInCheck {
                let checker = state.currentPlayer.opponent
                let streak = state.consecutiveCheckCount(for: checker)
                let suffix = streak >= 2 ? " · 连续将军×\(streak)" : ""
                return (session.isLocalTurn ? "轮到你 · 正在被将军" : "对方回合 · 将军") + suffix
            }
            return session.isLocalTurn ? "轮到你行动" : "等待对方行动"
        case .declined: return "邀请已被拒绝"
        case .cancelled: return "邀请已取消"
        case .finished(let winner):
            guard let winner else {
                if session.xiangqi?.drawReason == .threefoldRepetition { return "对局结束 · 三次重复和棋" }
                return "对局结束 · 和棋"
            }
            return winner == session.localPlayer ? "对局结束 · 你赢了" : "对局结束 · 对方获胜"
        }
    }

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 11) {
                    ZStack {
                        Circle().fill(VeilTheme.gold.opacity(0.10))
                        Image(systemName: session.game.icon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(VeilTheme.gold)
                    }
                    .frame(width: 42, height: 42)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(session.game.title)
                            .font(.headline)
                            .foregroundColor(VeilTheme.text)
                        Text(statusText)
                            .font(.caption)
                            .foregroundColor(session.isLocalTurn ? VeilTheme.gold : VeilTheme.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundColor(VeilTheme.tertiaryText)
                }

                HStack(spacing: 8) {
                    Label("E2EE", systemImage: "lock.fill")
                    Text("·")
                    Text(session.game == .tactical ? "\(session.moveCount) 道命令" : "\(session.moveCount) 手")
                    Text("·")
                    Text("#\(session.id.prefix(4))")
                    Spacer()
                    Text(session.status == .active ? "进入棋局" : "查看")
                        .fontWeight(.semibold)
                        .foregroundColor(VeilTheme.gold)
                }
                .font(.caption2.monospacedDigit())
                .foregroundColor(VeilTheme.tertiaryText)
            }
            .padding(14)
            .background(VeilTheme.elevated.opacity(0.92))
            .clipShape(VeilPanelShape(cut: 14, radius: 8))
            .overlay(VeilPanelShape(cut: 14, radius: 8).stroke(session.isLocalTurn ? VeilTheme.gold.opacity(0.28) : VeilTheme.hairline, lineWidth: 1))
            .overlay(alignment: .topLeading) {
                Rectangle()
                    .fill(session.isLocalTurn ? VeilTheme.gold : VeilTheme.hairline)
                    .frame(width: session.isLocalTurn ? 42 : 18, height: 1)
                    .padding(.leading, 12)
            }
        }
        .buttonStyle(VeilPressStyle())
        .accessibilityLabel("\(session.game.title)，\(statusText)，点击打开棋局")
    }
}

struct MiniGameSessionView: View {
    @ObservedObject var model: AppModel
    let conversation: ConversationSummary
    let sessionID: String

    @Environment(\.dismiss) private var dismiss
    @State private var messages: [ChatMessage] = []
    @State private var session: MiniGameSessionSnapshot?
    @State private var selectedXiangqiIndex: Int?
    @State private var isPlaying = false

    private let playbackTimer = Timer.publish(every: 0.75, on: .main, in: .common).autoconnect()
    @State private var showsResignConfirmation = false
    @State private var showsRules = false
    @State private var showsReplay = false
    @State private var showsAgentAssistant = false
    @State private var isSending = false
    @State private var observedMoveCount = 0
    @State private var reloadGeneration = 0

    private var latestLocalGameMessage: ChatMessage? {
        messages.reversed().first { message in
            guard message.isOutgoing else { return false }
            if let packet = MiniGameCodec.decode(message.body) {
                return packet.sessionID == sessionID
            }
            if let envelope = TacticalV2.WireCodecV2.decode(message.body) {
                return envelope.sessionID == sessionID
            }
            return false
        }
    }

    var body: some View {
        Group {
            if let session {
                VStack(spacing: 12) {
                    MiniGameStatusHeader(session: session)
                        .padding(.horizontal, 14)
                        .padding(.top, 10)

                    MiniGameLinkStatusView(
                        bluetooth: model.bluetooth,
                        sessions: model.sessions,
                        peerIdentityID: conversation.peerIdentityID,
                        latestGameMessage: latestLocalGameMessage
                    )
                    .padding(.horizontal, 14)

                    switch session.status {
                    case .invited:
                        invitationView(session)
                    case .active:
                        activeGameView(session)
                    case .declined:
                        terminalView(session: session, icon: "xmark.circle", title: "邀请已被拒绝", detail: "这局没有开始，你可以直接再发起一局。")
                    case .cancelled:
                        terminalView(session: session, icon: "minus.circle", title: "邀请已取消", detail: "这局没有开始，你可以随时重新邀请对方。")
                    case .finished(let winner):
                        let draw = winner == nil
                        terminalView(
                            session: session,
                            icon: draw ? "equal.circle" : (winner == session.localPlayer ? "trophy.fill" : "flag.checkered"),
                            title: draw ? "和棋" : (winner == session.localPlayer ? "你赢了" : "对方获胜"),
                            detail: finishDetail(session)
                        )
                    }
                    Spacer(minLength: 0)
                }
                .background(VeilAmbientBackground().ignoresSafeArea())
                .navigationTitle(session.game.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        if session.status == .active {
                            Button {
                                model.updateAgentGameContext(session, conversation: conversation)
                                showsAgentAssistant = true
                            } label: {
                                Image(systemName: "sparkles")
                            }
                            .foregroundColor(VeilTheme.gold)
                            .accessibilityLabel("打开灵核对局助手")
                        }
                        Button { showsRules = true } label: {
                            Image(systemName: "questionmark.circle")
                        }
                        .foregroundColor(VeilTheme.gold)
                        if session.status == .active {
                            Button("认输") { showsResignConfirmation = true }
                                .foregroundColor(.red.opacity(0.85))
                        }
                    }
                }
                .sheet(isPresented: $showsRules) {
                    MiniGameRulesView(game: session.game)
                }
                .sheet(isPresented: $showsReplay) {
                    MiniGameReplayView(messages: messages, sessionID: session.id)
                }
                .sheet(isPresented: $showsAgentAssistant) {
                    AgentGameAssistantSheet(model: model, conversation: conversation, session: session)
                }
            } else {
                ProgressView("读取对局…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(VeilAmbientBackground().ignoresSafeArea())
            }
        }
        .onAppear {
            model.agent.setComputeFocus(.gameDecision)
            model.maleCNS.prepareFromBundle()
            reload(notify: false)
        }
        .onChange(of: model.messagesRevision) { _ in
            selectedXiangqiIndex = nil
            reload(notify: true)
        }
        .onDisappear {
            model.agent.setComputeFocus(.idle)
            model.gameIntelligence.clear(sessionID: sessionID)
        }
        .alert("确认认输？", isPresented: $showsResignConfirmation) {
            Button("继续对局", role: .cancel) {}
            Button("认输", role: .destructive) {
                send(command: .resign, turn: session?.moveCount ?? 0, move: nil)
            }
        } message: {
            Text("对方会立即被判定为本局获胜者。")
        }
    }

    @ViewBuilder
    private func invitationView(_ session: MiniGameSessionSnapshot) -> some View {
        if session.hostIsLocal {
            VStack(spacing: 16) {
                Image(systemName: "hourglass")
                    .font(.system(size: 48, weight: .light))
                    .foregroundColor(VeilTheme.gold)
                Text("邀请已发送")
                    .font(.title3.bold())
                    .foregroundColor(VeilTheme.text)
                Text("等待对方接受 \(session.game.title) 对局。邀请和响应都在当前加密会话内传输。")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(VeilTheme.secondaryText)
                HStack(spacing: 10) {
                    Button("查看规则") { showsRules = true }
                        .buttonStyle(VeilGameSecondaryButtonStyle())
                    Button("撤回邀请") { send(command: .resign, turn: 0, move: nil) }
                        .buttonStyle(VeilGameSecondaryButtonStyle())
                        .disabled(isSending)
                }
            }
            .padding(28)
        } else {
            VStack(spacing: 18) {
                ZStack {
                    Circle().fill(VeilTheme.gold.opacity(0.08)).frame(width: 92, height: 92)
                    Image(systemName: session.game.icon)
                        .font(.system(size: 48, weight: .light))
                        .foregroundColor(VeilTheme.gold)
                }
                Text("对方邀请你玩\(session.game.title)")
                    .font(.title3.bold())
                    .foregroundColor(VeilTheme.text)
                Text(session.game.subtitle)
                    .font(.subheadline)
                    .foregroundColor(VeilTheme.secondaryText)
                Button("先看规则") { showsRules = true }
                    .foregroundColor(VeilTheme.gold)
                    .font(.caption.weight(.semibold))
                HStack(spacing: 12) {
                    Button("拒绝") { send(command: .decline, turn: 0, move: nil) }
                        .buttonStyle(VeilGameSecondaryButtonStyle())
                        .disabled(isSending)
                    Button("接受") { send(command: .accept, turn: 0, move: nil) }
                        .buttonStyle(VeilGamePrimaryButtonStyle())
                        .disabled(isSending)
                }
            }
            .padding(24)
        }
    }

    @ViewBuilder
    private func activeGameView(_ session: MiniGameSessionSnapshot) -> some View {
        switch session.game {
        case .gomoku:
            if let state = session.gomoku {
                GomokuBoardView(state: state, localPlayer: session.localPlayer, enabled: session.isLocalTurn && !isSending) { index in
                    send(command: .move, turn: session.moveCount, move: .gomoku(index: index))
                }
                .padding(.horizontal, 12)
            }
        case .xiangqi:
            if let state = session.xiangqi {
                XiangqiBoardView(
                    state: state,
                    localPlayer: session.localPlayer,
                    enabled: session.isLocalTurn && !isSending,
                    selectedIndex: $selectedXiangqiIndex,
                    onSelection: { model.haptics.selection() }
                ) { from, to in
                    send(command: .move, turn: session.moveCount, move: .xiangqi(from: from, to: to))
                }
                .padding(.horizontal, 14)
            }
        case .ludo:
            if let state = session.ludo {
                LudoBoardView(
                    state: state,
                    sessionID: session.id,
                    localPlayer: session.localPlayer,
                    enabled: session.isLocalTurn && !isSending,
                    onRoll: { model.haptics.impact() }
                ) { piece in
                    send(command: .move, turn: session.moveCount, move: .ludo(piece: piece))
                }
                .padding(.horizontal, 14)
            }
        case .tactical:
            if let state = session.tactical {
                TacticalV2LaunchGateView(
                    model: model,
                    conversation: conversation,
                    session: session,
                    messages: messages,
                    legacyState: state,
                    legacyEnabled: session.isLocalTurn && !isSending,
                    onLegacyMove: { from, to in
                        send(command: .move, turn: session.moveCount, move: .tactical(from: from, to: to))
                    },
                    onLegacyPass: {
                        send(command: .move, turn: session.moveCount, move: .tacticalPass())
                    }
                )
            }
        }
    }

    private func terminalView(session: MiniGameSessionSnapshot, icon: String, title: String, detail: String) -> some View {
        VStack(spacing: 15) {
            ZStack {
                Circle().fill(VeilTheme.gold.opacity(0.08)).frame(width: 92, height: 92)
                Image(systemName: icon)
                    .font(.system(size: 48, weight: .light))
                    .foregroundColor(VeilTheme.gold)
            }
            Text(title)
                .font(.title2.bold())
                .foregroundColor(VeilTheme.text)
            Text(detail)
                .multilineTextAlignment(.center)
                .font(.subheadline)
                .foregroundColor(VeilTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            if let duration = session.duration, session.moveCount > 0 {
                HStack(spacing: 12) {
                    Label(session.game == .tactical ? "\(session.moveCount) 道命令" : "\(session.moveCount) 手", systemImage: "number")
                    Label("约 " + formatDuration(duration), systemImage: "clock")
                }
                .font(.caption.monospacedDigit())
                .foregroundColor(VeilTheme.tertiaryText)
            }

            VStack(spacing: 10) {
                if session.moveCount > 0 {
                    Button("回放棋局") { showsReplay = true }
                        .buttonStyle(VeilGameSecondaryButtonStyle())
                }
                Button("再来一局") { rematch(session.game) }
                    .buttonStyle(VeilGamePrimaryButtonStyle())
                    .disabled(isSending)
                Button("返回小游戏") { dismiss() }
                    .buttonStyle(VeilGameSecondaryButtonStyle())
            }
            .padding(.top, 6)
        }
        .padding(28)
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 { return String(format: "%d:%02d:%02d", hours, minutes, seconds) }
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func finishDetail(_ session: MiniGameSessionSnapshot) -> String {
        if session.endedByResignation { return "对局因认输结束。完整操作记录仍保存在当前端到端加密聊天历史中。" }
        if session.game == .gomoku, session.gomoku?.isDraw == true { return "棋盘已满，双方和棋。棋局记录仍可从加密历史完整恢复。" }
        if session.game == .xiangqi, session.xiangqi?.endedByNoLegalMove == true {
            return "一方已无合法着法，对局结束。棋局记录仍保存在当前端到端加密聊天历史中。"
        }
        if session.game == .tactical, let state = session.tactical {
            if state.isDraw { return "八回合结束，双方胜利点相同，本局和局。全部命令仍可从加密历史重建。" }
            return "官渡战役已经结束：曹军 \(state.caoVictoryPoints) 胜利点，袁军 \(state.yuanVictoryPoints) 胜利点。完整命令记录仍保存在当前端到端加密聊天历史中。"
        }
        return "胜负已经确认。完整操作记录仍保存在当前端到端加密聊天历史中。"
    }

    private func send(command: MiniGameCommand, turn: Int, move: MiniGameMove?) {
        guard !isSending, let session else { return }
        isSending = true
        let packet = MiniGamePacket(sessionID: session.id, game: session.game, command: command, turn: turn, move: move)
        do {
            try model.sessions.sendMiniGamePacket(packet, to: conversation.peerIdentityID)
            model.haptics.send()
            selectedXiangqiIndex = nil
            reload(notify: false)
        } catch {
            model.alertMessage = error.localizedDescription
            model.haptics.error()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { isSending = false }
    }

    private func rematch(_ game: MiniGameKind) {
        guard !isSending else { return }
        isSending = true
        let packet = MiniGamePacket(game: game, command: .invite)
        do {
            try model.sessions.sendMiniGamePacket(packet, to: conversation.peerIdentityID)
            model.haptics.resolved()
            dismiss()
        } catch {
            model.alertMessage = error.localizedDescription
            model.haptics.error()
        }
        isSending = false
    }

    private func reload(notify: Bool) {
        reloadGeneration &+= 1
        let generation = reloadGeneration
        let oldCount = observedMoveCount
        let oldStatus = session?.status
        let loaded = model.database.fetchMessages(conversationID: conversation.id)
        let newSession = MiniGameSessionBuilder.session(id: sessionID, from: loaded)
        guard generation == reloadGeneration else { return }
        messages = loaded
        session = newSession
        if let newSession {
            model.updateAgentGameContext(newSession, conversation: conversation)
        }
        let newCount = newSession?.moveCount ?? 0
        if notify, newCount > oldCount, newSession?.isLocalTurn == true {
            model.haptics.receive()
        }
        if notify, let newSession, case .finished = newSession.status {
            if oldStatus != newSession.status { model.haptics.resolved() }
        }
        observedMoveCount = newCount
    }
}

private struct MiniGameReplayView: View {
    let messages: [ChatMessage]
    let sessionID: String

    @Environment(\.dismiss) private var dismiss
    @State private var frames: [MiniGameReplayFrame] = []
    @State private var selectedIndex = 0
    @State private var isLoading = true
    @State private var selectedXiangqiIndex: Int?
    @State private var isPlaying = false

    private let playbackTimer = Timer.publish(every: 0.75, on: .main, in: .common).autoconnect()

    private var currentFrame: MiniGameReplayFrame? {
        guard !frames.isEmpty else { return nil }
        return frames[min(max(0, selectedIndex), frames.count - 1)]
    }

    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("整理加密棋谱…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let frame = currentFrame {
                    ScrollView {
                        VStack(spacing: 14) {
                            replayHeader(frame)
                            replayBoard(frame.snapshot)
                            replayControls
                        }
                        .padding(14)
                    }
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 36, weight: .light))
                            .foregroundColor(VeilTheme.secondaryText)
                        Text("没有可回放的棋谱")
                            .font(.headline)
                            .foregroundColor(VeilTheme.text)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(VeilAmbientBackground().ignoresSafeArea())
            .navigationTitle("棋局回放")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }.foregroundColor(VeilTheme.gold)
                }
            }
        }
        .navigationViewStyle(.stack)
        .onAppear(perform: loadFrames)
        .onReceive(playbackTimer) { _ in
            guard isPlaying, !frames.isEmpty else { return }
            if selectedIndex >= frames.count - 1 {
                isPlaying = false
            } else {
                selectedIndex += 1
                selectedXiangqiIndex = nil
            }
        }
        .onDisappear { isPlaying = false }
    }

    private func replayHeader(_ frame: MiniGameReplayFrame) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(VeilTheme.gold.opacity(0.10))
                Image(systemName: frame.snapshot.game.icon)
                    .foregroundColor(VeilTheme.gold)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text(frame.label)
                    .font(.headline)
                    .foregroundColor(VeilTheme.text)
                Text("步骤 \(frame.index + 1) / \(frames.count) · \(frame.snapshot.game.title)")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(VeilTheme.secondaryText)
            }
            Spacer()
            Text("#\(frame.snapshot.id.prefix(4))")
                .font(.caption2.monospaced())
                .foregroundColor(VeilTheme.tertiaryText)
        }
        .padding(12)
        .background(VeilTheme.elevated.opacity(0.82))
        .clipShape(VeilPanelShape(cut: 9, radius: 6))
    }

    @ViewBuilder
    private func replayBoard(_ snapshot: MiniGameSessionSnapshot) -> some View {
        switch snapshot.game {
        case .gomoku:
            if let state = snapshot.gomoku {
                GomokuBoardView(state: state, localPlayer: snapshot.localPlayer, enabled: false) { _ in }
            }
        case .xiangqi:
            if let state = snapshot.xiangqi {
                XiangqiBoardView(
                    state: state,
                    localPlayer: snapshot.localPlayer,
                    enabled: false,
                    selectedIndex: $selectedXiangqiIndex,
                    onSelection: {}
                ) { _, _ in }
            }
        case .ludo:
            if let state = snapshot.ludo {
                LudoReplayBoardView(state: state, localPlayer: snapshot.localPlayer)
            }
        case .tactical:
            if let state = snapshot.tactical {
                TacticalReplayBoardView(state: state, localPlayer: snapshot.localPlayer)
            }
        }
    }

    private var replayControls: some View {
        VStack(spacing: 10) {
            if frames.count > 1 {
                Slider(
                    value: Binding(
                        get: { Double(selectedIndex) },
                        set: { selectedIndex = Int($0.rounded()); selectedXiangqiIndex = nil }
                    ),
                    in: 0...Double(frames.count - 1),
                    step: 1
                )
                .tint(VeilTheme.gold)
            }

            HStack(spacing: 10) {
                Button {
                    isPlaying = false
                    selectedIndex = max(0, selectedIndex - 1)
                    selectedXiangqiIndex = nil
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(VeilGameSecondaryButtonStyle())
                .disabled(selectedIndex <= 0)
                .accessibilityLabel("上一步")

                Button {
                    if selectedIndex >= frames.count - 1 { selectedIndex = 0 }
                    isPlaying.toggle()
                } label: {
                    Label(isPlaying ? "暂停" : "自动回放", systemImage: isPlaying ? "pause.fill" : "play.fill")
                }
                .buttonStyle(VeilGamePrimaryButtonStyle())
                .disabled(frames.count <= 1)

                Button {
                    isPlaying = false
                    selectedIndex = min(max(0, frames.count - 1), selectedIndex + 1)
                    selectedXiangqiIndex = nil
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(VeilGameSecondaryButtonStyle())
                .disabled(selectedIndex >= frames.count - 1)
                .accessibilityLabel("下一步")
            }
        }
        .padding(.top, 2)
    }

    private func loadFrames() {
        isLoading = true
        let source = messages
        let id = sessionID
        DispatchQueue.global(qos: .userInitiated).async {
            let built = MiniGameSessionBuilder.replay(sessionID: id, from: source)
            DispatchQueue.main.async {
                frames = built
                selectedIndex = max(0, built.count - 1)
                isLoading = false
            }
        }
    }
}

private struct LudoReplayBoardView: View {
    let state: LudoState
    let localPlayer: MiniGamePlayer

    var body: some View {
        VStack(spacing: 10) {
            LudoTrackView(state: state, localPlayer: localPlayer, enabled: false, legalPieces: []) { _ in }
                .aspectRatio(1, contentMode: .fit)
            HStack(spacing: 10) {
                Label("上一骰 \(state.lastDice)", systemImage: "die.face.\(state.lastDice).fill")
                Spacer()
                Text("红 \(state.finishedCount(for: .host))/4 · 蓝 \(state.finishedCount(for: .guest))/4")
            }
            .font(.caption.monospacedDigit())
            .foregroundColor(VeilTheme.secondaryText)
        }
    }
}

private struct MiniGameStatusHeader: View {
    let session: MiniGameSessionSnapshot

    private var title: String {
        switch session.status {
        case .invited: return session.hostIsLocal ? "等待接受" : "收到邀请"
        case .active:
            if session.game == .xiangqi, let state = session.xiangqi, state.isCurrentPlayerInCheck {
                let checker = state.currentPlayer.opponent
                let streak = state.consecutiveCheckCount(for: checker)
                let suffix = streak >= 2 ? " · 连续×\(streak)" : ""
                return (session.isLocalTurn ? "轮到你 · 将军" : "对方被将军") + suffix
            }
            return session.isLocalTurn ? "轮到你" : "对方回合"
        case .declined: return "已拒绝"
        case .cancelled: return "已取消"
        case .finished(let winner):
            guard let winner else { return "和棋" }
            return winner == session.localPlayer ? "你赢了" : "对方获胜"
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(session.isLocalTurn ? VeilTheme.gold : VeilTheme.secondaryText.opacity(0.4))
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(VeilTheme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                if session.status == .active {
                    Text(session.game == .tactical ? "第 \(session.moveCount + 1) 道命令" : "第 \(session.moveCount + 1) 手")
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(VeilTheme.secondaryText)
                }
            }
            Spacer()
            HStack(spacing: 5) {
                Image(systemName: "lock.fill").font(.system(size: 8))
                Text("E2EE · #\(session.id.prefix(4))")
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .font(.caption2.monospaced())
            .foregroundColor(VeilTheme.tertiaryText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(VeilTheme.elevated.opacity(0.85))
        .clipShape(VeilPanelShape(cut: 10, radius: 6))
    }
}

struct GomokuBoardView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let state: GomokuState
    let localPlayer: MiniGamePlayer
    let enabled: Bool
    let onMove: (Int) -> Void

    private let starPoints = [48, 56, 112, 168, 176]

    var body: some View {
        VStack(spacing: 11) {
            GeometryReader { proxy in
                let side = min(proxy.size.width, proxy.size.height)
                let margin = side * 0.055
                let step = (side - margin * 2) / CGFloat(GomokuState.size - 1)

                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color(red: 0.42, green: 0.29, blue: 0.15).opacity(0.46))
                        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(VeilTheme.hairline, lineWidth: 1))

                    gomokuGrid(side: side, margin: margin, step: step)
                        .stroke(Color.white.opacity(0.27), lineWidth: 0.65)

                    ForEach(starPoints, id: \.self) { index in
                        let point = gomokuPoint(index: index, margin: margin, step: step)
                        Circle().fill(Color.white.opacity(0.42)).frame(width: 4.2, height: 4.2).position(point)
                    }

                    if state.winningLine.count >= 5,
                       let first = state.winningLine.first,
                       let last = state.winningLine.last {
                        Path { path in
                            path.move(to: gomokuPoint(index: first, margin: margin, step: step))
                            path.addLine(to: gomokuPoint(index: last, margin: margin, step: step))
                        }
                        .stroke(VeilTheme.gold.opacity(0.9), style: StrokeStyle(lineWidth: max(2, step * 0.12), lineCap: .round))
                    }

                    ForEach(0..<(GomokuState.size * GomokuState.size), id: \.self) { index in
                        let value = state.value(at: index)
                        if value != 0 {
                            let point = gomokuPoint(index: index, margin: margin, step: step)
                            Circle()
                                .fill(value == 1 ? Color.black.opacity(0.96) : Color.white.opacity(0.96))
                                .frame(width: step * 0.82, height: step * 0.82)
                                .overlay(
                                    Circle().stroke(state.lastMove == index ? VeilTheme.gold : (value == 1 ? Color.white.opacity(0.16) : Color.black.opacity(0.24)), lineWidth: state.lastMove == index ? 2 : 0.7)
                                )
                                .shadow(color: Color.black.opacity(0.28), radius: 1.4, x: 0, y: 1)
                                .position(point)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }

                    if enabled {
                        Color.clear
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onEnded { gesture in
                                        let col = Int(round((gesture.location.x - margin) / step))
                                        let row = Int(round((gesture.location.y - margin) / step))
                                        guard (0..<GomokuState.size).contains(row), (0..<GomokuState.size).contains(col) else { return }
                                        let point = CGPoint(x: margin + CGFloat(col) * step, y: margin + CGFloat(row) * step)
                                        let dx = gesture.location.x - point.x
                                        let dy = gesture.location.y - point.y
                                        guard sqrt(dx * dx + dy * dy) <= step * 0.52 else { return }
                                        let index = row * GomokuState.size + col
                                        guard state.value(at: index) == 0 else { return }
                                        onMove(index)
                                    }
                            )
                    }
                }
                .frame(width: side, height: side)
                .animation(reduceMotion || VeilDevicePerformance.current.transferVisualComplexity == .minimal ? nil : VeilMotion.resolve, value: state.moveCount)
            }
            .aspectRatio(1, contentMode: .fit)

            HStack {
                Text(localPlayer == .host ? "你执黑 · 先手" : "你执白 · 后手")
                Spacer()
                Text(enabled ? "轻触交叉点落子" : "等待对方")
            }
            .font(.caption)
            .foregroundColor(enabled ? VeilTheme.gold : VeilTheme.secondaryText)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("五子棋棋盘，已进行 \(state.moveCount) 手，\(enabled ? "轮到你落子" : "等待对方落子")")
    }

    private func gomokuPoint(index: Int, margin: CGFloat, step: CGFloat) -> CGPoint {
        CGPoint(x: margin + CGFloat(index % GomokuState.size) * step,
                y: margin + CGFloat(index / GomokuState.size) * step)
    }

    private func gomokuGrid(side: CGFloat, margin: CGFloat, step: CGFloat) -> Path {
        Path { path in
            for value in 0..<GomokuState.size {
                let offset = margin + CGFloat(value) * step
                path.move(to: CGPoint(x: margin, y: offset))
                path.addLine(to: CGPoint(x: side - margin, y: offset))
                path.move(to: CGPoint(x: offset, y: margin))
                path.addLine(to: CGPoint(x: offset, y: side - margin))
            }
        }
    }
}

struct XiangqiBoardView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let state: XiangqiState
    let localPlayer: MiniGamePlayer
    let enabled: Bool
    @Binding var selectedIndex: Int?
    let onSelection: () -> Void
    let onMove: (Int, Int) -> Void

    private var localSide: XiangqiSide { localPlayer == .host ? .red : .black }
    private var legalDestinations: Set<Int> {
        guard let selectedIndex else { return [] }
        return Set(state.legalDestinations(from: selectedIndex, actor: localPlayer))
    }

    var body: some View {
        VStack(spacing: 10) {
            if state.isCurrentPlayerInCheck {
                HStack(spacing: 7) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(state.currentPlayer == localPlayer ? "你正在被将军" : "对方正在被将军")
                }
                .font(.caption.weight(.semibold))
                .foregroundColor(VeilTheme.gold)
            }

            GeometryReader { proxy in
                let width = proxy.size.width
                let height = proxy.size.height
                let margin = min(width, height) * 0.055
                let stepX = (width - margin * 2) / CGFloat(XiangqiState.columns - 1)
                let stepY = (height - margin * 2) / CGFloat(XiangqiState.rows - 1)
                let destinations = legalDestinations

                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color(red: 0.39, green: 0.25, blue: 0.13).opacity(0.50))
                        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(VeilTheme.hairline, lineWidth: 1))

                    xiangqiGrid(width: width, height: height, margin: margin, stepX: stepX, stepY: stepY)
                        .stroke(Color.white.opacity(0.29), lineWidth: 0.72)

                    HStack {
                        Text(localPlayer == .host ? "楚河" : "汉界")
                        Spacer(minLength: stepX)
                        Text(localPlayer == .host ? "汉界" : "楚河")
                    }
                    .font(.system(size: max(10, stepX * 0.32), weight: .semibold, design: .serif))
                    .foregroundColor(Color.white.opacity(0.22))
                    .frame(width: max(0, width - margin * 2 - stepX * 1.1))
                    .position(x: width / 2, y: margin + stepY * 4.5)

                    if let last = state.lastMove, let from = last.from, let to = last.to {
                        Path { path in
                            path.move(to: xiangqiPoint(index: from, width: width, height: height, margin: margin, stepX: stepX, stepY: stepY))
                            path.addLine(to: xiangqiPoint(index: to, width: width, height: height, margin: margin, stepX: stepX, stepY: stepY))
                        }
                        .stroke(VeilTheme.gold.opacity(0.26), style: StrokeStyle(lineWidth: 2.4, lineCap: .round, dash: [3, 4]))
                    }

                    ForEach(Array(destinations), id: \.self) { index in
                        let point = xiangqiPoint(index: index, width: width, height: height, margin: margin, stepX: stepX, stepY: stepY)
                        Circle()
                            .fill(VeilTheme.gold.opacity(state.piece(at: index) == nil ? 0.58 : 0.22))
                            .frame(width: state.piece(at: index) == nil ? 9 : stepX * 0.73, height: state.piece(at: index) == nil ? 9 : stepX * 0.73)
                            .overlay(Circle().stroke(VeilTheme.gold.opacity(0.75), lineWidth: state.piece(at: index) == nil ? 0 : 1.5))
                            .position(point)
                    }

                    ForEach(0..<(XiangqiState.rows * XiangqiState.columns), id: \.self) { index in
                        if let piece = state.piece(at: index) {
                            let point = xiangqiPoint(index: index, width: width, height: height, margin: margin, stepX: stepX, stepY: stepY)
                            ZStack {
                                Circle()
                                    .fill(piece.side == .red ? Color(red: 0.50, green: 0.08, blue: 0.07).opacity(0.97) : Color.black.opacity(0.94))
                                    .overlay(Circle().stroke(selectedIndex == index ? VeilTheme.gold : Color.white.opacity(0.24), lineWidth: selectedIndex == index ? 2.3 : 0.8))
                                    .shadow(color: Color.black.opacity(0.32), radius: 1.5, x: 0, y: 1)
                                Text(piece.glyph)
                                    .font(.system(size: max(13, stepX * 0.43), weight: .bold, design: .serif))
                                    .foregroundColor(piece.side == .red ? Color(red: 1.0, green: 0.78, blue: 0.48) : Color.white.opacity(0.92))
                            }
                            .frame(width: stepX * 0.78, height: stepX * 0.78)
                            .position(point)
                        }
                    }

                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onEnded { gesture in
                                    guard enabled else { return }
                                    guard let index = xiangqiIndex(at: gesture.location, width: width, height: height, margin: margin, stepX: stepX, stepY: stepY) else { return }
                                    handleTap(index)
                                }
                        )
                }
            }
            .aspectRatio(0.86, contentMode: .fit)
            .animation(reduceMotion || VeilDevicePerformance.current.transferVisualComplexity == .minimal ? nil : VeilMotion.resolve, value: state.moveCount)

            HStack {
                Text(localSide == .red ? "你执红 · 先手" : "你执黑 · 后手")
                Spacer()
                if selectedIndex != nil { Text("高亮处可落子") }
                else { Text(enabled ? "选择棋子" : "等待对方") }
            }
            .font(.caption)
            .foregroundColor(enabled ? VeilTheme.gold : VeilTheme.secondaryText)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("中国象棋棋盘，已进行 \(state.moveCount) 手，\(state.isCurrentPlayerInCheck ? "当前有将军，" : "")\(enabled ? "轮到你" : "等待对方")")
    }

    private func displayCoordinates(for index: Int) -> (row: Int, col: Int) {
        let row = index / XiangqiState.columns
        let col = index % XiangqiState.columns
        if localPlayer == .host { return (row, col) }
        return (XiangqiState.rows - 1 - row, XiangqiState.columns - 1 - col)
    }

    private func actualIndex(displayRow: Int, displayCol: Int) -> Int {
        if localPlayer == .host { return displayRow * XiangqiState.columns + displayCol }
        let row = XiangqiState.rows - 1 - displayRow
        let col = XiangqiState.columns - 1 - displayCol
        return row * XiangqiState.columns + col
    }

    private func xiangqiPoint(index: Int, width: CGFloat, height: CGFloat, margin: CGFloat, stepX: CGFloat, stepY: CGFloat) -> CGPoint {
        let c = displayCoordinates(for: index)
        return CGPoint(x: margin + CGFloat(c.col) * stepX, y: margin + CGFloat(c.row) * stepY)
    }

    private func xiangqiIndex(at location: CGPoint, width: CGFloat, height: CGFloat, margin: CGFloat, stepX: CGFloat, stepY: CGFloat) -> Int? {
        let col = Int(round((location.x - margin) / stepX))
        let row = Int(round((location.y - margin) / stepY))
        guard (0..<XiangqiState.rows).contains(row), (0..<XiangqiState.columns).contains(col) else { return nil }
        let point = CGPoint(x: margin + CGFloat(col) * stepX, y: margin + CGFloat(row) * stepY)
        guard abs(location.x - point.x) <= stepX * 0.48, abs(location.y - point.y) <= stepY * 0.48 else { return nil }
        return actualIndex(displayRow: row, displayCol: col)
    }

    private func xiangqiGrid(width: CGFloat, height: CGFloat, margin: CGFloat, stepX: CGFloat, stepY: CGFloat) -> Path {
        Path { path in
            for row in 0..<XiangqiState.rows {
                let y = margin + CGFloat(row) * stepY
                path.move(to: CGPoint(x: margin, y: y))
                path.addLine(to: CGPoint(x: width - margin, y: y))
            }
            for col in 0..<XiangqiState.columns {
                let x = margin + CGFloat(col) * stepX
                if col == 0 || col == XiangqiState.columns - 1 {
                    path.move(to: CGPoint(x: x, y: margin))
                    path.addLine(to: CGPoint(x: x, y: height - margin))
                } else {
                    path.move(to: CGPoint(x: x, y: margin))
                    path.addLine(to: CGPoint(x: x, y: margin + stepY * 4))
                    path.move(to: CGPoint(x: x, y: margin + stepY * 5))
                    path.addLine(to: CGPoint(x: x, y: height - margin))
                }
            }
            let x3 = margin + stepX * 3
            let x5 = margin + stepX * 5
            let y0 = margin
            let y2 = margin + stepY * 2
            let y7 = margin + stepY * 7
            let y9 = margin + stepY * 9
            path.move(to: CGPoint(x: x3, y: y0)); path.addLine(to: CGPoint(x: x5, y: y2))
            path.move(to: CGPoint(x: x5, y: y0)); path.addLine(to: CGPoint(x: x3, y: y2))
            path.move(to: CGPoint(x: x3, y: y7)); path.addLine(to: CGPoint(x: x5, y: y9))
            path.move(to: CGPoint(x: x5, y: y7)); path.addLine(to: CGPoint(x: x3, y: y9))
        }
    }

    private func handleTap(_ index: Int) {
        guard enabled else { return }
        if let selected = selectedIndex {
            let legal = state.legalDestinations(from: selected, actor: localPlayer)
            if legal.contains(index) {
                onMove(selected, index)
                selectedIndex = nil
                return
            }
            if state.piece(at: index)?.side == localSide {
                let destinations = state.legalDestinations(from: index, actor: localPlayer)
                selectedIndex = destinations.isEmpty ? nil : index
                if selectedIndex != nil { onSelection() }
            } else {
                selectedIndex = nil
            }
        } else if state.piece(at: index)?.side == localSide,
                  !state.legalDestinations(from: index, actor: localPlayer).isEmpty {
            selectedIndex = index
            onSelection()
        }
    }
}

struct LudoBoardView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let state: LudoState
    let sessionID: String
    let localPlayer: MiniGamePlayer
    let enabled: Bool
    let onRoll: () -> Void
    let onMove: (Int) -> Void

    @State private var revealedTurn: Int?
    @State private var rollPulse = 0

    private var legalPieces: [Int] { state.legalPieces(sessionID: sessionID) }
    private var dice: Int { state.expectedDice(sessionID: sessionID) }
    private var isRevealed: Bool { revealedTurn == state.turn }
    private var canAct: Bool { enabled && isRevealed }

    var body: some View {
        VStack(spacing: 14) {
            LudoTrackView(state: state, localPlayer: localPlayer, enabled: canAct, legalPieces: legalPieces, onMove: onMove)
                .aspectRatio(1, contentMode: .fit)

            HStack(spacing: 12) {
                diceCard
                progressCard(player: .host, title: localPlayer == .host ? "你 · 红方" : "对方 · 红方")
                progressCard(player: .guest, title: localPlayer == .guest ? "你 · 蓝方" : "对方 · 蓝方")
            }

            if enabled && !isRevealed {
                Button {
                    onRoll()
                    rollPulse &+= 1
                    if reduceMotion || VeilDevicePerformance.current.transferVisualComplexity == .minimal {
                        revealedTurn = state.turn
                    } else {
                        withAnimation(VeilMotion.resolve) { revealedTurn = state.turn }
                    }
                } label: {
                    Label("掷骰子", systemImage: "die.face.5.fill")
                }
                .buttonStyle(VeilGamePrimaryButtonStyle())
                .accessibilityHint("点数由双方共同可验证的当前对局状态确定")
            } else if canAct && legalPieces.isEmpty {
                Button("没有可走棋子 · 结束本回合") { onMove(-1) }
                    .buttonStyle(VeilGamePrimaryButtonStyle())
            } else if canAct {
                Text("选择发光的飞机 · 掷出 6 或撞回对方后可继续")
                    .font(.caption)
                    .foregroundColor(VeilTheme.secondaryText)
            } else {
                Text("等待对方完成这一回合")
                    .font(.caption)
                    .foregroundColor(VeilTheme.secondaryText)
            }
        }
        .onChange(of: state.turn) { _ in
            revealedTurn = nil
        }
        .onChange(of: enabled) { active in
            if !active { revealedTurn = nil }
        }
    }

    private var diceCard: some View {
        VStack(spacing: 5) {
            Image(systemName: canAct ? "die.face.\(dice).fill" : (enabled ? "die.face.5" : "questionmark.square.dashed"))
                .font(.system(size: 31, weight: .regular))
                .foregroundColor(VeilTheme.gold)
                .rotationEffect(.degrees(canAct && !reduceMotion ? Double(rollPulse % 4) * 90 : 0))
            Text(canAct ? "点数 \(dice)" : (enabled ? "待掷" : "等待"))
                .font(.caption.weight(.semibold))
                .foregroundColor(VeilTheme.text)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(VeilTheme.elevated.opacity(0.82))
        .clipShape(VeilPanelShape(cut: 8, radius: 6))
    }

    private func progressCard(player: MiniGamePlayer, title: String) -> some View {
        VStack(spacing: 5) {
            Text("\(state.finishedCount(for: player))/4")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(player == localPlayer ? VeilTheme.gold : VeilTheme.text)
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(VeilTheme.secondaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(VeilTheme.elevated.opacity(0.82))
        .clipShape(VeilPanelShape(cut: 8, radius: 6))
    }
}

private struct LudoTrackView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let state: LudoState
    let localPlayer: MiniGamePlayer
    let enabled: Bool
    let legalPieces: [Int]
    let onMove: (Int) -> Void

    private let safeSquares: Set<Int> = [0, 13, 26, 39]

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: side / 2, y: side / 2)
            let radius = side * 0.40

            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(VeilTheme.elevated.opacity(0.72))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(VeilTheme.hairline, lineWidth: 1))

                ForEach(0..<LudoState.trackLength, id: \.self) { position in
                    let point = ringPoint(position: position, center: center, radius: radius)
                    Circle()
                        .fill(safeSquares.contains(position) ? VeilTheme.gold.opacity(0.62) : Color.white.opacity(0.17))
                        .frame(width: safeSquares.contains(position) ? 6 : 4, height: safeSquares.contains(position) ? 6 : 4)
                        .position(point)
                }

                Circle()
                    .fill(Color.black.opacity(0.16))
                    .frame(width: side * 0.34, height: side * 0.34)
                    .overlay(
                        VStack(spacing: 4) {
                            Image(systemName: "airplane")
                                .font(.system(size: 27, weight: .light))
                                .foregroundColor(VeilTheme.gold)
                            Text("飞行棋")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(VeilTheme.text)
                            Text("第 \(state.turn + 1) 回合")
                                .font(.caption2.monospacedDigit())
                                .foregroundColor(VeilTheme.secondaryText)
                        }
                    )
                    .position(center)

                ForEach([MiniGamePlayer.host, .guest], id: \.rawValue) { player in
                    ForEach(0..<LudoState.pieceCount, id: \.self) { index in
                        let progress = state.pieces(for: player)[index]
                        let point = piecePoint(player: player, pieceIndex: index, progress: progress, center: center, radius: radius, side: side)
                        let isLocal = player == localPlayer
                        let isLegal = isLocal && enabled && legalPieces.contains(index)
                        Button {
                            if isLegal { onMove(index) }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(player == .host ? Color(red: 0.52, green: 0.10, blue: 0.09) : Color(red: 0.10, green: 0.31, blue: 0.58))
                                    .overlay(Circle().stroke(isLegal ? VeilTheme.gold : Color.white.opacity(0.24), lineWidth: isLegal ? 2.5 : 0.8))
                                    .shadow(color: isLegal ? VeilTheme.gold.opacity(0.28) : Color.black.opacity(0.22), radius: isLegal ? 5 : 1.5)
                                Image(systemName: progress == LudoState.finishProgress ? "flag.fill" : "airplane")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(Color.white.opacity(0.92))
                            }
                            .frame(width: isLegal ? 31 : 27, height: isLegal ? 31 : 27)
                        }
                        .buttonStyle(.plain)
                        .disabled(!isLegal)
                        .position(point)
                        .accessibilityLabel("\(isLocal ? "你的" : "对方的")第 \(index + 1) 架飞机，\(progressText(progress))")
                    }
                }
            }
            .frame(width: side, height: side)
            .animation(reduceMotion || VeilDevicePerformance.current.transferVisualComplexity == .minimal ? nil : VeilMotion.transit, value: state.turn)
        }
        .accessibilityElement(children: .contain)
    }

    private func ringPoint(position: Int, center: CGPoint, radius: CGFloat) -> CGPoint {
        let angle = (Double(position) / Double(LudoState.trackLength)) * Double.pi * 2 - Double.pi / 2
        return CGPoint(x: center.x + CGFloat(cos(angle)) * radius,
                       y: center.y + CGFloat(sin(angle)) * radius)
    }

    private func piecePoint(player: MiniGamePlayer, pieceIndex: Int, progress: Int, center: CGPoint, radius: CGFloat, side: CGFloat) -> CGPoint {
        if progress == -1 {
            let baseX = player == .host ? side * 0.23 : side * 0.77
            let baseY = player == .host ? side * 0.77 : side * 0.23
            let dx: CGFloat = pieceIndex % 2 == 0 ? -16 : 16
            let dy: CGFloat = pieceIndex < 2 ? -16 : 16
            return CGPoint(x: baseX + dx, y: baseY + dy)
        }
        if progress == LudoState.finishProgress {
            let dx: CGFloat = (CGFloat(pieceIndex) - 1.5) * 7
            let y = player == .host ? center.y + 28 : center.y - 28
            return CGPoint(x: center.x + dx, y: y)
        }
        if progress >= LudoState.trackLength {
            let lane = CGFloat(progress - LudoState.trackLength + 1) / CGFloat(LudoState.finishProgress - LudoState.trackLength + 1)
            let start = ringPoint(position: player == .host ? 51 : 25, center: center, radius: radius)
            let end = CGPoint(x: center.x, y: player == .host ? center.y + 24 : center.y - 24)
            return CGPoint(x: start.x + (end.x - start.x) * lane,
                           y: start.y + (end.y - start.y) * lane)
        }
        if let track = state.trackPosition(player: player, progress: progress) {
            let base = ringPoint(position: track, center: center, radius: radius)
            let offset = (CGFloat(pieceIndex) - 1.5) * 2.2
            return CGPoint(x: base.x + offset, y: base.y + offset)
        }
        return center
    }

    private func progressText(_ progress: Int) -> String {
        switch progress {
        case -1: return "待起飞"
        case LudoState.finishProgress: return "已到达终点"
        case 0..<LudoState.trackLength: return "轨道第 \(progress + 1) 格"
        default: return "终点冲刺第 \(progress - LudoState.trackLength + 1) 格"
        }
    }
}

private struct MiniGameRulesView: View {
    let game: MiniGameKind
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 12) {
                        Image(systemName: game.icon)
                            .font(.system(size: 30, weight: .light))
                            .foregroundColor(VeilTheme.gold)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(game.title).font(.title2.bold()).foregroundColor(VeilTheme.text)
                            Text(game.subtitle).font(.caption).foregroundColor(VeilTheme.secondaryText)
                        }
                    }
                    ruleText
                    HStack(alignment: .top, spacing: 9) {
                        Image(systemName: "lock.shield.fill").foregroundColor(VeilTheme.gold)
                        Text("对局事件通过当前 VeilLink 端到端加密聊天传输；断线后会依靠已有 ACK、Outbox 与聊天历史继续恢复。")
                            .font(.caption)
                            .foregroundColor(VeilTheme.secondaryText)
                    }
                    .padding(12)
                    .background(VeilTheme.elevated.opacity(0.8))
                    .clipShape(VeilPanelShape(cut: 9, radius: 6))
                }
                .padding(18)
            }
            .background(VeilAmbientBackground().ignoresSafeArea())
            .navigationTitle("规则")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }.foregroundColor(VeilTheme.gold)
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    @ViewBuilder
    private var ruleText: some View {
        switch game {
        case .gomoku:
            VStack(alignment: .leading, spacing: 10) {
                rule("黑方先手，双方轮流在 15×15 棋盘交叉点落子。")
                rule("横、竖或斜线连续形成至少五枚同色棋子即获胜。")
                rule("棋盘全部落满且无人连成五子时判和。")
            }
        case .xiangqi:
            VStack(alignment: .leading, spacing: 10) {
                rule("红方先手；车、马、炮、相/象、仕/士、帅/将、兵/卒按标准中国象棋规则移动。")
                rule("包含蹩马腿、塞象眼、炮架、九宫、不过河的象，以及将帅照面限制。")
                rule("不能主动把自己的将帅置于被攻击状态；被将军后必须应将。无任何合法着法时判负。")
            }
        case .ludo:
            VStack(alignment: .leading, spacing: 10) {
                rule("双方各四架飞机；掷出 6 才能从基地起飞。")
                rule("落在非安全格上的对方飞机会将其撞回基地；掷出 6 或成功撞回后获得额外回合。")
                rule("进入终点跑道必须点数刚好，四架飞机全部到达终点即获胜。")
            }
        case .tactical:
            VStack(alignment: .leading, spacing: 10) {
                rule("《官渡决战》是原创轻量历史兵棋：曹军为主方、袁军为客方，每方每个阶段最多下达两道命令。")
                rule("算子在六角格地图上机动；林地、丘陵会提高移动成本，河道不可直接通过，渡口可通行。")
                rule("不同兵种拥有不同机动与战斗能力；补给中断会降低行动效率，靠近中军可获得指挥支援。")
                rule("占领官渡、乌巢、白马可在整轮结束时获得胜利点；达到 8 VP、攻占敌方大营或击溃敌方中军均可获胜。")
                rule("战斗结算使用双方都能由同一加密历史重算的确定性骰值，因此断线重连后结果仍保持一致。")
                rule("本作只借鉴桌面兵棋的表现形式，地图、数值与规则均为 VeilLink 原创轻量化设计，并非对现成桌游的数字复刻。")
            }
        }
    }

    private func rule(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Circle().fill(VeilTheme.gold).frame(width: 5, height: 5).padding(.top, 7)
            Text(text)
                .font(.subheadline)
                .foregroundColor(VeilTheme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct VeilGamePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundColor(Color.black.opacity(0.88))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(VeilTheme.gold.opacity(configuration.isPressed ? 0.72 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct VeilGameSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundColor(VeilTheme.text)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.white.opacity(configuration.isPressed ? 0.10 : 0.055))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
