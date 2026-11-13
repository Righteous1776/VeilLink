# Owner V29 product request: display the Republic of China flag correctly

## Reproduction hypothesis (not yet device-verified)
Some iOS devices with mainland China region settings or hardware variants do not supply the U+1F1F9/U+1F1FC regional-indicator emoji glyph, causing a missing box instead of the flag. Emojipedia documents the historical iOS behavior. Rendering an asset inside the app avoids reliance on the operating system's Emoji glyph. System emoji keyboard and other applications remain under iOS control.

## Proposed fix
- New `VeilROCFlagText` render adapter detects exactly the two regional indicator Unicode scalars for TW. When absent, return unmodified `Text(verbatim:)`; when present, concatenate native SwiftUI Text and a small self-rendered 24×16pt original-color image in each occurrence. This permits normal inline multi-line wrapping and does not create per-word HStacks.
- New `VeilROCFlagView` explicit graphical component for future pickers/identity views. No binary assets, third-party font, image download or system locale override.
- Draw according to Article 4 of the ROC National Emblem and Flag Act: red 3:2 field, upper-left blue canton one quarter total area, twelve white pointed sun rays, white central disk separated from rays by a blue gap. Sun disk radius = 1/8 blue canton width, ray tips at 2 disk radii, blue circle thickness = white sun diameter /15. Ray-tip 30° angle. RGB nominal red #FE0000, blue #000095. Orientation tip north/south/east/west.
  Legal specification: 《中華民國國徽國旗法》Articles 3–4, Ministry of Interior publication. Design proportions confirmed against the official law.
- Update human conversation list/contact titles, conversation previews, chat text bubbles, quoted replies, agent chat, LingCore text bubbles, and local identity display name to use `VeilROCFlagText.render`. Speech labels use `中华民国国旗`. Original message payload, quotes, drafts, database, sharing/copying and end-to-end encryption remain byte-for-byte untouched. Other flags remain unchanged.
- Setting page A9 advisory health UI: before `lastEvaluatedAt`, show H-- / 未评估 with neutral indicator and explicit caution; never use default green/100 as though sampled. A10-only display still reads A10 state without being replaced by A9 data.

## Scope limits
- Does NOT enable flag input in the system emoji keyboard or change the iOS system's global glyph/font behavior. Raw text rendered in unmodified third-party views may still show a missing box, as may editors controlled by UIKit. Integrate the same component in additional UI surfaces if later acceptance reveals a gap.
- This is UI-only and proposed; do not claim verified on iPhone 7 or iPhone SE2 until screenshot review in both China and non-China region settings.
- No external network call, media, protocol, AES/chats, message content rewriting, passwords, metrics semantics, A9 health classifier mutation or protected assets.

## Revised Owner request: optional dual-input panel (2026-11-13)
- Provide **two explicit send paths**: native two-regional-indicator Unicode characters inserted into the ordinary draft (no automatic send), and an optional generated 3:2 image attachment sent only after a second confirmation through existing ImageTranscoder + SessionCoordinator.sendImage.
- Default hidden in the chat composer. A neutral `输入扩展` entry lives in the existing "+" menu; upon an 8 ASCII digit access code passing SHA256 digest verification, a compact 36pt input-options icon is visible until ChatView disappears. The menu can lock itself again.
- Access input is accepted in a SecureField and discarded immediately; no code, failed attempt, token, or enabled status is saved to the database, Keychain, logs, analytics, chat or backups. Five failed attempts in one ChatView disable this session's entry. New ChatView instance resets eligibility. This gate is explicitly **NOT security**, because fixed 8-digit secrets in public client code are recoverable.
- The chosen historical mnemonic is documented privately to the Owner, NOT included verbatim in code or public-facing UI labels. The source identifies the optional action generically. **Do not promise source invisibility**: old PR history, graphic geometry and reachable strings remain inspectable in a public repository.
- In regions where the OS fails to draw the Unicode flag, the existing `VeilROCFlagText.render()` displays it in an app-owned inline image after sending. The recipient outside VeilLink may still see a missing glyph, so the actual image-attachment mode is also available.
- No private Apple keyboard extensions or system-level Emoji keyboard changes, no change to protected Wire or encryption.
