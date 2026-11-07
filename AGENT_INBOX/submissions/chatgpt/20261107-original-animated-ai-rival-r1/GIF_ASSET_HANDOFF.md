# GIF handoff for integration / Generated 2026-11-07

## What was actually generated
- Name in app bundle: `GrokBotLoop.gif`
- Source conversation file: `VeilLink_Grok_bot_loop_compact.gif`
- 112×112, 24 frames, 110 milliseconds/frame, NETSCAPE2 infinite looping
- Bytes: 89204
- SHA-256: `38b25a123bf5ec1234db598d577e2de0f049b60567a75d1b24af33a755282429`
- Optional larger 200×200 GIF, 189575 B, SHA-256 `998c03288535838642bcc3d1edb8777478989efd0f34966b6373d27b7acbaefb`
- Intended bundle path: `VeilLink/Resources/GrokBotLoop.gif`
- Input reference supplied by Owner: minimal black circular shape with two white eyes, source image shared in this chat. GIF generated in this chat, transparent-background version.

## Governance boundary
**The actual GIF bytes are NOT committed to GitHub.** Current `AGENT_INBOX/ASSET_GRANTS.json` grants only `game-agent` and extensions PNG/JPEG/WebP/glTF/OBJ/USDZ. No active GIF asset grant for chatgpt or live product source grant. Renaming GIF as .png or smuggling base64 into a source file would violate the resource gate and is NOT done.

## Once a valid grant is issued
1. Verify GIF bytes match SHA-256 above.
2. Stage the binary under an explicitly authorized asset scope, then integrate `VeilLink/Resources/GrokBotLoop.gif` in a Governor integration branch; ensure XcodeGen actually copies it into the app bundle.
3. Apply this PR's updated `PATCH.diff`; it now automatically detects `GrokBotLoop.gif` and plays through `UIImageView`; without it, the existing vector Canvas mascot remains as a fallback.
4. Confirm the original 9 AI game screens and Owner Mode toggle from this PR are still present, and resolve overlap with PR #159 (solo match save), #128 (side selection), #141/#129 (game lobby).
5. Test background/inactive pause, low-power appearance, iOS15 memory and frametimes, Reduce Motion; never claim tests ran before executing them.

## User download
The GIF files are provided directly within the generating ChatGPT conversation; GitHub can't fetch sandbox file attachments through its connector. This handoff documents exact bytes for subsequent authorized incorporation.
