import Foundation

extension TacticalV2 {
    enum ChatMessageAdapterV2 {
        static func records(
            from messages: [ChatMessage],
            sessionID: String
        ) -> [WireRecordV2] {
            messages.compactMap { message in
                guard let envelope = WireCodecV2.decode(message.body),
                      envelope.sessionID == sessionID else {
                    return nil
                }
                return WireRecordV2(
                    body: message.body,
                    isOutgoing: message.isOutgoing,
                    sentAt: message.sentAt
                )
            }
        }
    }
}
