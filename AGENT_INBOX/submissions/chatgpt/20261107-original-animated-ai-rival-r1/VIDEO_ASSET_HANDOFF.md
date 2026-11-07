# R4 — User-authored full animation asset handoff

## Source verified from owner upload
- Filename: ScreenRecording_11-07-2026 午前11-19-38_1.mp4
- Format: H.264 514x512, 30 fps, 921 frames, 30.700 s; includes AAC audio
- Byte size: 4,213,583
- SHA-256: 411ae1ee2a979cae4edf9b56b0676420174c88e87461fcd8264409d17111e7fe

## App-ready resource created during this conversation
- Filename: GrokBotFull.mp4
- Byte size: 3,719,439
- SHA-256: 462dea06791e79e7410ec25a69ded8abae6244ed751f2099be8d72778290e788
- Format: same H.264 514x512 30fps video, 921 frames, 30.700 s; no video recode, audio track omitted
- Remux command: ffmpeg -i SOURCE.mp4 -map 0:v:0 -c:v copy -an -movflags +faststart GrokBotFull.mp4
- App bundle target: VeilLink/Resources/GrokBotFull.mp4
- The actual file is attached in the downloadable VeilLink_GrokBot_FullAnimation_R4.zip from this conversation.

## How to complete integration
1. Obtain the app-ready ZIP attachment from user conversation and verify exact SHA-256 above.
2. With appropriate asset/live-lane Governor grant, place MP4 bytes at VeilLink/Resources/GrokBotFull.mp4 and ensure XcodeGen embeds it as a bundle resource.
3. Reconcile and apply approved source patch from PR #160. It prioritizes MP4 via AVPlayerLooper and falls back to GIF or Canvas if missing.
4. Verify the independent Owner Mode Grok bot toggle and all nine human-vs-AI screens. Test iOS15.8.3+ and idle/inactive/Reduce Motion transitions.
5. Confirm full repeat cycle quality and media performance; only then merge and release.

**Important:** The PR carries only Inbox text source and asset instructions. The MP4 bytes are not committed due to the current Asset Drop quota/extension/agent restriction.