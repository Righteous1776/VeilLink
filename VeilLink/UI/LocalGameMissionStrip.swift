import SwiftUI

struct LocalGameMissionStrip: View {
    let session: MiniGameSessionSnapshot

    private var mission: LocalGameMission {
        LocalGameMissionDirector.mission(for: session.game, sessionID: session.id)
    }

    private var progress: LocalGameMissionProgress {
        LocalGameMissionEvaluator.progress(for: mission, session: session)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 9) {
                ZStack {
                    Circle()
                        .fill(VeilTheme.gold.opacity(0.10))
                        .frame(width: 34, height: 34)
                    Image(systemName: progress.completed ? "checkmark.seal.fill" : mission.systemImage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(VeilTheme.goldBright)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("MISSION · " + mission.code)
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .tracking(0.8)
                        .foregroundColor(VeilTheme.mutedGold)
                    Text(mission.title)
                        .font(.caption.weight(.bold))
                        .foregroundColor(VeilTheme.text)
                }

                Spacer(minLength: 6)

                Text(progress.completed ? "COMPLETE" : progress.label)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(progress.completed ? VeilTheme.goldBright : VeilTheme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.black.opacity(0.28))
                    Capsule()
                        .fill(VeilTheme.gold)
                        .frame(width: max(4, proxy.size.width * progress.fraction))
                }
            }
            .frame(height: 5)

            Text(mission.detail)
                .font(.caption2)
                .foregroundColor(VeilTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(
            VeilInstrumentPlate(
                shape: RoundedRectangle(cornerRadius: 14, style: .continuous),
                emphasized: progress.completed
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(VeilTheme.hairline, lineWidth: 0.8)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("本局任务 " + mission.title)
        .accessibilityValue(progress.label)
    }
}
