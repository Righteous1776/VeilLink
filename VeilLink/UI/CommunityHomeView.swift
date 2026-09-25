import SwiftUI
import UIKit

struct VeilCommunityHomeView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var community: VeilCommunityStore
    @ObservedObject var mesh: VeilMeshOverlayRouter
    @ObservedObject var lanTurbo: LANTransport
    @State private var selectedRoom: VeilCommunityRoom?
    @State private var showsCreate = false
    @State private var joinCode = ""

    init(model: AppModel) {
        self.model = model
        community = model.community
        mesh = model.meshRouter
        lanTurbo = model.lanTurbo
    }

    var body: some View {
        VeilStableScrollView {
            VStack(spacing: 14) {
                meshCard
                lanBoostCard
                if community.rooms.isEmpty {
                    emptyCard
                } else {
                    ForEach(community.rooms) { room in
                        Button {
                            selectedRoom = room
                            model.haptics.selection()
                        } label: {
                            roomRow(room)
                        }
                        .buttonStyle(VeilPressStyle())
                    }
                }
                discoveredSection
                joinSection
            }
        }
        .background(VeilAmbientBackground())
        .navigationTitle("群组与频道")
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    community.announceDiscoverableRooms()
                    model.haptics.selection()
                } label: { Image(systemName: "arrow.triangle.2.circlepath") }
                .accessibilityLabel("刷新附近频道")

                Button { showsCreate = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("创建群组或频道")
            }
        }
        .sheet(isPresented: $showsCreate) {
            VeilCommunityCreateSheet(model: model)
        }
        .sheet(item: $selectedRoom) { room in
            NavigationView {
                VeilCommunityRoomView(model: model, roomID: room.id)
            }
            .navigationViewStyle(StackNavigationViewStyle())
        }
        .onAppear { community.announceDiscoverableRooms() }
    }

    private var meshCard: some View {
        HStack(spacing: 12) {
            VeilIconDisc(systemName: "point.3.connected.trianglepath.dotted", size: 42, highlighted: mesh.snapshot.neighborCount > 0)
            VStack(alignment: .leading, spacing: 4) {
                Text("MESH RELAY")
                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                    .tracking(1)
                    .foregroundColor(VeilTheme.mutedGold)
                Text(mesh.relayEnabled ? "多跳中继已开启" : "仅本机收发")
                    .font(.headline)
                Text("邻居 \(mesh.snapshot.neighborCount) · 已转发 \(mesh.snapshot.relayedPacketCount) · 去重 \(mesh.snapshot.droppedDuplicateCount)")
                    .font(.caption2)
                    .foregroundColor(VeilTheme.secondaryText)
            }
            Spacer()
            Toggle("", isOn: $mesh.relayEnabled)
                .labelsHidden()
                .tint(VeilTheme.gold)
        }
        .veilCard(emphasized: mesh.relayEnabled)
        .veilDynamicGlow(active: mesh.relayEnabled && mesh.snapshot.neighborCount > 0, emphasized: true)
    }

    private var lanBoostCard: some View {
        HStack(spacing: 12) {
            VeilIconDisc(systemName: "wifi", size: 38, highlighted: lanTurbo.connectedPeerCount > 0)
            VStack(alignment: .leading, spacing: 3) {
                Text("LAN / P2P BOOST")
                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                    .tracking(1)
                    .foregroundColor(VeilTheme.mutedGold)
                Text(lanTurbo.statusText).font(.caption.weight(.semibold))
                Text("同网 TCP 优先 · Apple P2P Wi-Fi 可参与建链")
                    .font(.caption2).foregroundColor(VeilTheme.secondaryText)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { lanTurbo.peerToPeerBoostEnabled },
                set: { value in
                    lanTurbo.peerToPeerBoostEnabled = value
                    lanTurbo.refresh()
                }
            ))
            .labelsHidden()
            .tint(VeilTheme.gold)
        }
        .veilCard(emphasized: lanTurbo.connectedPeerCount > 0)
    }

    private var emptyCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.3.sequence.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundColor(VeilTheme.goldBright)
            Text("还没有群组或频道").font(.headline)
            Text("普通群组使用邀请密钥；公开频道可以在附近 Mesh 中被发现。")
                .font(.caption)
                .foregroundColor(VeilTheme.secondaryText)
                .multilineTextAlignment(.center)
            Button("创建第一个房间") { showsCreate = true }
                .buttonStyle(VeilPhysicalButtonStyle(accent: true))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .veilCard()
    }

    private func roomRow(_ room: VeilCommunityRoom) -> some View {
        HStack(spacing: 12) {
            VeilIconDisc(systemName: room.kind == .publicChannel ? "megaphone.fill" : "person.3.fill", size: 40, highlighted: room.kind == .publicChannel)
            VStack(alignment: .leading, spacing: 4) {
                Text(room.title).font(.headline).foregroundColor(VeilTheme.text)
                HStack(spacing: 7) {
                    Text(room.kind == .publicChannel ? "PUBLIC CHANNEL" : "PRIVATE GROUP")
                    Text("·")
                    Text("TTL \(room.defaultHopLimit)")
                }
                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                .foregroundColor(VeilTheme.mutedGold)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption.bold()).foregroundColor(VeilTheme.tertiaryText)
        }
        .padding(12)
        .background(VeilTheme.elevated.opacity(0.78))
        .clipShape(VeilPanelShape(cut: 12, radius: 7))
        .overlay(VeilPanelShape(cut: 12, radius: 7).stroke(VeilTheme.hairline, lineWidth: 1))
    }

    @ViewBuilder
    private var discoveredSection: some View {
        if !community.discoveredChannels.isEmpty {
            VStack(alignment: .leading, spacing: 9) {
                Text("附近公开频道")
                    .font(.headline)
                    .foregroundColor(VeilTheme.goldBright)
                ForEach(community.discoveredChannels) { channel in
                    HStack(spacing: 10) {
                        VeilIconDisc(systemName: "dot.radiowaves.left.and.right", size: 34, highlighted: true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(channel.title).fontWeight(.semibold)
                            Text("Mesh \(channel.hopCount) hop · \(channel.ageText)")
                                .font(.caption2).foregroundColor(VeilTheme.secondaryText)
                        }
                        Spacer()
                        Button("加入") {
                            if let room = community.joinDiscoveredChannel(channel.id) { selectedRoom = room }
                        }
                        .buttonStyle(.bordered)
                        .tint(VeilTheme.gold)
                    }
                    .veilCard()
                }
            }
        }
    }

    private var joinSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("邀请加入").font(.headline).foregroundColor(VeilTheme.goldBright)
            TextField("粘贴群组邀请代码", text: $joinCode)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(.caption, design: .monospaced))
                .padding(10)
                .background(VeilTheme.elevated)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            Button("验证并加入") {
                if let room = community.join(inviteCode: joinCode) {
                    selectedRoom = room
                    joinCode = ""
                    model.haptics.resolved()
                } else {
                    model.haptics.warning()
                }
            }
            .buttonStyle(VeilPhysicalButtonStyle(accent: false))
        }
        .veilCard()
    }
}

private struct VeilCommunityRoomView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var community: VeilCommunityStore
    let roomID: UUID
    @State private var draft = ""
    @State private var anonymous = false
    @State private var copiedInvite = false
    @Environment(\.dismiss) private var dismiss

    init(model: AppModel, roomID: UUID) {
        self.model = model
        community = model.community
        self.roomID = roomID
    }

    private var room: VeilCommunityRoom? { community.rooms.first(where: { $0.id == roomID }) }
    private var records: [VeilCommunityMessageRecord] { community.messages(in: roomID) }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(records) { record in
                            messageBubble(record)
                                .id(record.id)
                        }
                    }
                    .padding(12)
                }
                .onChange(of: records.count) { _ in
                    if let last = records.last?.id { withAnimation { proxy.scrollTo(last, anchor: .bottom) } }
                }
            }
            Divider().background(VeilTheme.hairline)
            composer
        }
        .background(VeilAmbientBackground())
        .navigationTitle(room?.title ?? "群聊")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) { Button("完成") { dismiss() } }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    guard let code = community.inviteCode(roomID: roomID) else { return }
                    UIPasteboard.general.string = code
                    copiedInvite = true
                    model.haptics.resolved()
                } label: { Image(systemName: copiedInvite ? "checkmark" : "person.badge.plus") }
                .accessibilityLabel("复制邀请代码")
            }
        }
    }

    private func messageBubble(_ record: VeilCommunityMessageRecord) -> some View {
        HStack {
            if record.isOutgoing { Spacer(minLength: 42) }
            VStack(alignment: record.isOutgoing ? .trailing : .leading, spacing: 3) {
                Text(record.senderMode == .anonymous ? record.senderAlias : (record.senderIdentityID ?? record.senderAlias))
                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                    .foregroundColor(record.senderMode == .anonymous ? VeilTheme.mutedGold : VeilTheme.goldBright)
                Text(record.body)
                    .foregroundColor(VeilTheme.text)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 8)
                    .background(record.isOutgoing ? VeilTheme.gold.opacity(0.12) : VeilTheme.elevated)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text(record.sentAt, style: .time).font(.caption2).foregroundColor(VeilTheme.tertiaryText)
            }
            if !record.isOutgoing { Spacer(minLength: 42) }
        }
    }

    private var composer: some View {
        VStack(spacing: 8) {
            if room?.kind == .publicChannel {
                HStack {
                    Label(anonymous ? "匿名身份" : "真实身份", systemImage: anonymous ? "theatermasks.fill" : "person.crop.circle.badge.checkmark")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(VeilTheme.secondaryText)
                    Spacer()
                    Toggle("匿名", isOn: $anonymous).labelsHidden().tint(VeilTheme.gold)
                }
            }
            HStack(spacing: 8) {
                TextField("发送到房间", text: $draft)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 9)
                    .background(VeilTheme.elevated)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Button {
                    let text = draft
                    draft = ""
                    community.send(body: text, roomID: roomID, mode: anonymous ? .anonymous : .identified)
                    model.haptics.send()
                } label: {
                    Image(systemName: "arrow.up.circle.fill").font(.system(size: 28))
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .foregroundColor(VeilTheme.goldBright)
            }
        }
        .padding(10)
        .background(VeilTheme.panel.opacity(0.94))
    }
}

private struct VeilCommunityCreateSheet: View {
    @ObservedObject var model: AppModel
    @ObservedObject var community: VeilCommunityStore
    @State private var title = ""
    @State private var kind: VeilCommunityRoomKind = .privateGroup
    @Environment(\.dismiss) private var dismiss

    init(model: AppModel) {
        self.model = model
        community = model.community
    }

    var body: some View {
        NavigationView {
            Form {
                Section("房间") {
                    TextField("名称", text: $title)
                    Picker("类型", selection: $kind) {
                        Text("普通群聊").tag(VeilCommunityRoomKind.privateGroup)
                        Text("公开频道").tag(VeilCommunityRoomKind.publicChannel)
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    Text(kind == .privateGroup
                         ? "邀请制；房间密钥只通过邀请代码或可信 E2EE 链路分发。"
                         : "可被附近 Mesh 发现；任何拿到公开频道发现包的人都可以加入。匿名模式只隐藏频道内身份，不等于网络层匿名。")
                        .font(.caption)
                }
            }
            .navigationTitle("创建")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") {
                        if community.createRoom(title: title, kind: kind, discoverable: kind == .publicChannel) != nil {
                            model.haptics.resolved()
                            dismiss()
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
