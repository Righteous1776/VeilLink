import SwiftUI

struct LatticeClashLabView: View {
    @State private var state = LatticeClashState()

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: 5),
            count: LatticeClashState.size
        )
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.055, green: 0.065, blue: 0.085),
                    Color(red: 0.11, green: 0.12, blue: 0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    header
                    scoreDeck
                    board
                    turnDeck
                    rulesDeck
                }
                .padding(16)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("晶格争夺")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("LATTICE CLASH")
                        .font(.system(.caption, design: .monospaced).weight(.bold))
                        .tracking(1.4)
                        .foregroundColor(Color.cyan.opacity(0.86))
                    Text("晶格争夺 · Game Lab")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.white)
                }
                Spacer()
                Text("7×7")
                    .font(.caption.bold().monospacedDigit())
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.07))
                    .clipShape(Capsule())
            }

            Text("从两侧锚点扩张晶格。新节点若让敌方节点同时受到至少 3 个友方邻点支撑，会触发确定性链式转化。先控制 25 格者获胜。")
                .font(.caption)
                .foregroundColor(.white.opacity(0.62))
                .fixedSize(horizontal: false, vertical: true)
        }
        .panel()
    }

    private var scoreDeck: some View {
        HStack(spacing: 10) {
            scoreCard(
                title: "YOU",
                value: state.count(for: .host),
                color: .cyan,
                active: state.currentPlayer == .host && !state.isFinished
            )
            scoreCard(
                title: "BOT",
                value: state.count(for: .guest),
                color: .orange,
                active: state.currentPlayer == .guest && !state.isFinished
            )
            VStack(spacing: 4) {
                Text("TURN")
                    .font(.caption2.bold().monospaced())
                    .foregroundColor(.white.opacity(0.45))
                Text("\(state.turn)")
                    .font(.title3.bold().monospacedDigit())
                    .foregroundColor(.white)
                Text("/ \(LatticeClashState.maxTurns)")
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(.white.opacity(0.4))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.22))
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .panel()
    }

    private var board: some View {
        LazyVGrid(columns: columns, spacing: 5) {
            ForEach(0..<LatticeClashState.cellCount, id: \.self) { index in
                cellButton(index: index)
            }
        }
        .padding(9)
        .background(Color.black.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.28), radius: 16, y: 8)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("晶格争夺棋盘")
    }

    private var turnDeck: some View {
        VStack(spacing: 10) {
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: statusColor.opacity(0.8), radius: 4)
                Text(statusText)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white.opacity(0.84))
                Spacer()
                if let result = state.lastTurn, !result.captured.isEmpty {
                    Text("链式转化 +\(result.captured.count)")
                        .font(.caption2.bold().monospacedDigit())
                        .foregroundColor(.yellow.opacity(0.9))
                }
            }

            if state.isFinished {
                Button("重新布设晶格") {
                    state = LatticeClashState()
                }
                .buttonStyle(LatticeClashControlButtonStyle())
            } else {
                HStack {
                    Text("可落点 \(state.legalMoves(for: .host).count)")
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(.white.opacity(0.45))
                    Spacer()
                    Text("多数阈值 \(LatticeClashState.majorityCount)")
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(.white.opacity(0.45))
                }
            }
        }
        .panel()
    }

    private var rulesDeck: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("RULESET")
                .font(.caption2.bold().monospaced())
                .foregroundColor(.white.opacity(0.45))
            Text("• 只能在己方节点的八邻域空格中扩张。\n• 敌方节点被至少 3 个己方邻点包围时转化；转化会继续触发下一波。\n• 对手无合法着法时保留回合；双方都无法行动则按控制格数结算。\n• Bot 只搜索有限合法着法，使用同一规则引擎验证，没有随机数和模型资源。")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panel()
    }

    private func cellButton(index: Int) -> some View {
        let cell = state.cell(at: index)
        let legal = state.isLegal(
            move: LatticeClashMove(index: index),
            actor: .host
        )

        return Button {
            commitHumanMove(index: index)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(cellBackground(cell: cell, legal: legal))
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(
                                state.lastMove == index
                                    ? Color.white.opacity(0.8)
                                    : Color.white.opacity(0.055),
                                lineWidth: state.lastMove == index ? 1.5 : 0.8
                            )
                    )

                switch cell {
                case .host:
                    node(color: .cyan)
                case .guest:
                    node(color: .orange)
                case .empty:
                    if legal {
                        Circle()
                            .fill(Color.cyan.opacity(0.32))
                            .frame(width: 7, height: 7)
                    }
                }
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!legal || state.isFinished)
        .accessibilityLabel(cellAccessibility(index: index, cell: cell, legal: legal))
    }

    private func node(color: Color) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [Color.white.opacity(0.9), color],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 18
                )
            )
            .padding(7)
            .shadow(color: color.opacity(0.45), radius: 5)
    }

    private func cellBackground(cell: LatticeClashCell, legal: Bool) -> Color {
        switch cell {
        case .host:
            return Color.cyan.opacity(0.09)
        case .guest:
            return Color.orange.opacity(0.09)
        case .empty:
            return legal ? Color.cyan.opacity(0.06) : Color.white.opacity(0.025)
        }
    }

    private func scoreCard(
        title: String,
        value: Int,
        color: Color,
        active: Bool
    ) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 5) {
                Circle()
                    .fill(color)
                    .frame(width: 7, height: 7)
                Text(title)
                    .font(.caption2.bold().monospaced())
                    .foregroundColor(.white.opacity(0.5))
            }
            Text("\(value)")
                .font(.title2.bold().monospacedDigit())
                .foregroundColor(.white)
            Text(active ? "ACTIVE" : "STANDBY")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(active ? color : Color.white.opacity(0.28))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(Color.black.opacity(active ? 0.28 : 0.2))
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    private var statusColor: Color {
        if state.isFinished {
            return state.isDraw ? .yellow : (state.winner == .host ? .cyan : .orange)
        }
        return state.currentPlayer == .host ? .cyan : .orange
    }

    private var statusText: String {
        if state.isDraw {
            return "晶格锁定 · 平局"
        }
        if let winner = state.winner {
            return winner == .host ? "多数控制完成 · 你获胜" : "多数控制完成 · BOT 获胜"
        }
        return state.currentPlayer == .host ? "你的扩张窗口" : "BOT 正在计算"
    }

    private func commitHumanMove(index: Int) {
        var next = state
        guard next.apply(
            move: LatticeClashMove(index: index),
            actor: .host
        ) else {
            return
        }

        var safety = 0
        while !next.isFinished,
              next.currentPlayer == .guest,
              safety < LatticeClashState.maxTurns {
            guard let move = LatticeClashBot.chooseMove(in: next, actor: .guest),
                  next.apply(move: move, actor: .guest) else {
                break
            }
            safety += 1
        }

        withAnimation(.easeInOut(duration: 0.18)) {
            state = next
        }
    }

    private func cellAccessibility(
        index: Int,
        cell: LatticeClashCell,
        legal: Bool
    ) -> String {
        let coordinate = LatticeClashState.rowColumn(for: index)
        let owner: String
        switch cell {
        case .empty: owner = legal ? "空格，可落子" : "空格"
        case .host: owner = "你的节点"
        case .guest: owner = "BOT 节点"
        }
        return "第 \(coordinate.row + 1) 行，第 \(coordinate.column + 1) 列，\(owner)"
    }
}

private struct LatticeClashControlButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .foregroundColor(.black.opacity(0.82))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                LinearGradient(
                    colors: [
                        Color.cyan.opacity(configuration.isPressed ? 0.62 : 0.94),
                        Color.blue.opacity(configuration.isPressed ? 0.55 : 0.78)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

private extension View {
    func panel() -> some View {
        self
            .padding(13)
            .background(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.075),
                        Color.white.opacity(0.035)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 0.8)
            )
    }
}
