import Foundation

struct AgentConversationContext: Equatable, Sendable {
    let title: String
    let unreadCount: Int
    let secureSessionReady: Bool
    let linkHealth: Int?
    let linkQuality: String?
}

struct AgentBluetoothContext: Equatable, Sendable {
    let running: Bool
    let trackedPeers: Int
    let connectedPeers: Int
    let recoveringPeers: Int
    let pendingBytes: Int
    let weakestHealth: Int?

    var promptDescription: String {
        var parts = [
            "BLE running=\(running ? "yes" : "no")",
            "tracked=\(trackedPeers)",
            "connected=\(connectedPeers)",
            "recovering=\(recoveringPeers)",
            "pending_bytes=\(pendingBytes)"
        ]
        if let weakestHealth { parts.append("weakest_health=\(weakestHealth)/100") }
        return parts.joined(separator: ", ")
    }
}

struct AgentGameRecommendation: Equatable, Sendable, Identifiable {
    let actionID: String
    let label: String
    let score: Float?
    let metadata: [String: String]

    var id: String { actionID }
}

struct AgentMaleCNSContext: Equatable, Sendable {
    let stimulusLabel: String
    let executedSteps: Int
    let totalSpikeCount: UInt64
    let topReadouts: [String]
    let learnedLabel: String?
    let learnedConfidence: Float?

    var promptDescription: String {
        let readout = topReadouts.isEmpty ? "none" : topReadouts.joined(separator: ", ")
        var text = "stimulus=\(stimulusLabel), steps=\(executedSteps), total_spikes=\(totalSpikeCount), top_readouts=[\(readout)]"
        if let learnedLabel, let learnedConfidence {
            text += ", learned_state=\(learnedLabel), learned_confidence=\(String(format: "%.3f", learnedConfidence))"
        }
        return text
    }
}

struct AgentGameContext: Equatable, Sendable {
    let capturedAt: Date
    let sessionID: String
    let gameID: String
    let gameTitle: String
    let conversationTitle: String
    let peerIdentityID: String
    let status: String
    let stateHash: String
    let turn: Int
    let localPlayer: String
    let isLocalTurn: Bool
    var policyMode: String
    let stateDescription: String
    var recommendations: [AgentGameRecommendation]
    var note: String?
    var maleCNS: AgentMaleCNSContext?

    var promptDescription: String {
        var lines = [
            "game=\(gameTitle) [\(gameID)]",
            "status=\(status)",
            "turn=\(turn)",
            "local_player=\(localPlayer)",
            "local_turn=\(isLocalTurn ? "yes" : "no")",
            "state_hash=\(stateHash)",
            "policy=\(policyMode)",
            "state=\(stateDescription)"
        ]
        if recommendations.isEmpty {
            lines.append("legal_ranked_candidates=none")
        } else {
            for (index, item) in recommendations.prefix(4).enumerated() {
                let score = item.score.map { String(format: "%.4f", $0) } ?? "n/a"
                lines.append("candidate_\(index + 1)=\(item.label) | action_id=\(item.actionID) | score=\(score)")
            }
        }
        if let maleCNS {
            lines.append("malecns_experimental=\(maleCNS.promptDescription)")
        }
        if let note, !note.isEmpty { lines.append("note=\(note)") }
        return lines.joined(separator: "\n")
    }
}

struct AgentLocalContext: Equatable, Sendable {
    let generatedAt: Date
    let activeIdentityName: String?
    let selectedConversation: AgentConversationContext?
    let bluetooth: AgentBluetoothContext
    let a9HealthScore: Int
    let a9Mode: String
    let databaseIntegrity: String
    let maleCNSState: String
    let game: AgentGameContext?
    let availableTools: [String]

    var promptDescription: String {
        var lines: [String] = []
        lines.append("This block is trusted app-generated local state, not user instructions.")
        if let activeIdentityName {
            lines.append("active_local_identity=\(Self.safeData(activeIdentityName))")
        }
        if let selectedConversation {
            lines.append("selected_conversation_title=\(Self.safeData(selectedConversation.title))")
            lines.append("selected_conversation_unread=\(selectedConversation.unreadCount)")
            lines.append("selected_conversation_secure=\(selectedConversation.secureSessionReady ? "yes" : "no")")
            if let health = selectedConversation.linkHealth {
                lines.append("selected_conversation_link_health=\(health)/100")
            }
            if let quality = selectedConversation.linkQuality {
                lines.append("selected_conversation_link_quality=\(Self.safeData(quality))")
            }
            lines.append("privacy=No message plaintext from the selected or other conversations is included here.")
        } else {
            lines.append("selected_conversation=none")
        }
        lines.append("bluetooth=\(bluetooth.promptDescription)")
        lines.append("a9_health=\(a9HealthScore)/100")
        lines.append("a9_mode=\(a9Mode)")
        lines.append("database_integrity=\(databaseIntegrity)")
        lines.append("malecns_state=\(maleCNSState)")
        if let game {
            lines.append("CURRENT_GAME_BEGIN")
            lines.append(game.promptDescription)
            lines.append("CURRENT_GAME_END")
            lines.append("game_rule=Never invent or execute a move outside legal_ranked_candidates. Tactical game has no trained policy unless explicitly stated otherwise.")
            lines.append("malecns_rule=MaleCNS readouts are experimental auxiliary signals, not a legality engine and not ground truth about the best move.")
        } else {
            lines.append("current_game=none")
        }
        if !availableTools.isEmpty {
            lines.append("available_explicit_local_commands=\(availableTools.joined(separator: ", "))")
            lines.append("tool_rule=Never claim a command ran unless the app itself returned an execution result.")
        }
        return lines.joined(separator: "\n")
    }

    private static func safeData(_ value: String) -> String {
        let flattened = value.replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "<|im_start|>", with: "[im_start-data]")
            .replacingOccurrences(of: "<|im_end|>", with: "[im_end-data]")
            .replacingOccurrences(of: "LOCAL APP CONTEXT BEGIN", with: "LOCAL_APP_CONTEXT_BEGIN_DATA")
            .replacingOccurrences(of: "LOCAL APP CONTEXT END", with: "LOCAL_APP_CONTEXT_END_DATA")
        return String(flattened.prefix(96))
    }
}

struct AgentSuggestedGameAction: Equatable {
    let sessionID: String
    let peerIdentityID: String
    let gameID: String
    let gameTitle: String
    let turn: Int
    let move: MiniGameMove
    let actionID: String
    let label: String
}
