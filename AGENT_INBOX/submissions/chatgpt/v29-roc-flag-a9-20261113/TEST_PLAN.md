# Acceptance checklist

1. On Governor integration branch with Xcode/iOS 15 target: apply PATCH.diff to V29 main@eb487a1. Compile `VeilROCFlagText.swift` and run new `VeilROCFlagTextTests`, all messaging/local model UI tests and A9 health tests. NOT_RUN in Inbox.
2. iPhone 7 iOS 15.8.3 with region China mainland: in-app display of one or multiple Taiwan flag emoji in chat messages, names, quoted replies, conversation list previews, chat search and AI responses. Confirm correct 3:2 red-blue-white appearance with no missing-symbol box. Repeat in a non-China region, iPhone SE2 iOS 15.6.1, iPhone13 iOS26.
3. Check national flag design: blue canton exactly half width and half height; white sun/ring/twelve rays, rays correctly positioned and readable at 24×16pt, red and blue colors not overridden by sender/receiver message bubble foreground.
4. Copy, resend, quote, persistence and backup the same text; inspect raw Unicode scalars and byte hashes to confirm there is no mutation or appended image file on the wire.
5. VoiceOver reads "中华民国国旗" naturally in main chat, quote and AI previews, with no unlabelled inline image. Dynamic type wrapping, long messages and dark/light themes should be unaffected.
6. In Settings A9 mode before any evaluation: H--, 未评估 and grey indicator, no green/100 and no "nothing abnormal" claim. After evaluation show actual decision. A10-only mode remains independent.
7. Regression: no new artifacts/third-party licenses, signed resource changes or iOS Info.plist changes. Test offline; no system region permissions required. UI-only patch MUST NOT be mistaken for fixing BLE disconnects or native llama crashes.

## Dual-mode composer and privacy regression
8. On iPhone7 / iOS15: composer plus -> neutral input extension entry. Without access code there must be no extra icon; wrong length, invalid digits and 5 bad attempts fail closed. Correct historical code unlocks this ChatView only; leaving and reopening relocks. Never show the code in analytics, DiagnosticLogStore or debug snapshots.
9. After unlock choose `插入字符`, ensure draft gains U+1F1F9 U+1F1FC without automatic send. Send and compare raw payload to original sequence; verify PR #195 local visual fallback works.
10. After unlock choose `发送图形…`, require explicit `发送图片` confirmation. Check image is local 3:2 red/blue/white PNG and goes through existing ImageTranscoder, SessionCoordinator and encrypted image chunk handling. Drop/reconnect uses existing resend path. Verify temporary PNG is deleted on completion/failure.
11. On same device close ChatView/restart app; entry hidden, never retained in persisted user settings or drafts. Test failed image preparation error, large text, voice-mode toggle, system number keypad, VoiceOver; protected chat session/ACL unchanged.
12. Test input mode with iPhone SE2 and iOS26. iOS CI/XCTest and physical device acceptance remain NOT_RUN.
