# Acceptance checklist

1. On Governor integration branch with Xcode/iOS 15 target: apply PATCH.diff to V29 main@eb487a1. Compile `VeilROCFlagText.swift` and run new `VeilROCFlagTextTests`, all messaging/local model UI tests and A9 health tests. NOT_RUN in Inbox.
2. iPhone 7 iOS 15.8.3 with region China mainland: in-app display of one or multiple Taiwan flag emoji in chat messages, names, quoted replies, conversation list previews, chat search and AI responses. Confirm correct 3:2 red-blue-white appearance with no missing-symbol box. Repeat in a non-China region, iPhone SE2 iOS 15.6.1, iPhone13 iOS26.
3. Check national flag design: blue canton exactly half width and half height; white sun/ring/twelve rays, rays correctly positioned and readable at 24×16pt, red and blue colors not overridden by sender/receiver message bubble foreground.
4. Copy, resend, quote, persistence and backup the same text; inspect raw Unicode scalars and byte hashes to confirm there is no mutation or appended image file on the wire.
5. VoiceOver reads "中华民国国旗" naturally in main chat, quote and AI previews, with no unlabelled inline image. Dynamic type wrapping, long messages and dark/light themes should be unaffected.
6. In Settings A9 mode before any evaluation: H--, 未评估 and grey indicator, no green/100 and no "nothing abnormal" claim. After evaluation show actual decision. A10-only mode remains independent.
7. Regression: no new artifacts/third-party licenses, signed resource changes or iOS Info.plist changes. Test offline; no system region permissions required. UI-only patch MUST NOT be mistaken for fixing BLE disconnects or native llama crashes.
