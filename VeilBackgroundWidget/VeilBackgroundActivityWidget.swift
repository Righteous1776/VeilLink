import ActivityKit
import SwiftUI
import WidgetKit

@available(iOS 16.1, *)
struct VeilBackgroundActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: VeilBackgroundActivityAttributes.self) { context in
            HStack(spacing: 12) {
                Image(systemName: "antenna.radiowaves.left.and.right.circle.fill")
                    .font(.title2)
                VStack(alignment: .leading, spacing: 3) {
                    Text("VeilLink 后台连续性")
                        .font(.headline)
                    Text(context.state.mode)
                        .font(.caption.monospaced())
                    Text("BLE \(context.state.connectedBLEPeers) · LAN \(context.state.connectedLANPeers) · Mesh \(context.state.meshNeighbors)")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 4)
            .activityBackgroundTint(.black.opacity(0.92))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("B\(context.state.connectedBLEPeers) L\(context.state.connectedLANPeers)")
                        .font(.caption2.monospaced())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(context.state.mode)
                        Spacer()
                        Text("Mesh \(context.state.meshNeighbors)")
                    }
                    .font(.caption)
                }
            } compactLeading: {
                Image(systemName: "antenna.radiowaves.left.and.right")
            } compactTrailing: {
                Text("\(context.state.connectedBLEPeers + context.state.connectedLANPeers)")
                    .font(.caption2.monospaced())
            } minimal: {
                Image(systemName: "antenna.radiowaves.left.and.right")
            }
            .keylineTint(.yellow)
        }
    }
}

@main
@available(iOS 16.1, *)
struct VeilBackgroundWidgetBundle: WidgetBundle {
    var body: some Widget {
        VeilBackgroundActivityWidget()
    }
}
