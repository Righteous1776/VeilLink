# Grok bot R2 risk ledger
- This is a visually closer **independent imitation of general animation ideas**, not an exact reproduction, full original source port, extracted artwork, or licensed Grok character.
- Private experimentation and public app redistribution are different; changing the name alone does not transfer intellectual-property rights. Upstream explicitly disclaims permission to redistribute its copied materials.
- Blob shape and eye motion are independently authored parametric math; there is no copyrighted vertex table, binary asset, JS source or watermark.
- Canvas timing and alpha blending are plausible iOS15 APIs but require Apple compiler/hardware verification; 32 contour segments per frame may still be expensive on low-end devices.
- View-level OFF gate prevents Timeline view creation; Reduce Motion pauses animation, but mood/state changes can still redraw a static image.
- The nonofficial `Grok bot` feature label is requested by Owner. Before publication, assess whether that label creates confusion with xAI's official brand.
- Existing source collisions with #159, #128, #141 and #129; single PR update does not integrate protected product code. No Xcode/iOS build/IPA.

- Media asset is intentionally absent from PR branch: GIF playback is present in proposal code but will use fallback Canvas until an authorized binary is staged and bundled. Do not claim that PR #160 contains an actual GIF or the product has been modified.
- Native UIImage animatedImage ignores varied individual GIF frame delays, but generated 24 frames use uniform 110ms durations so this does not affect timing.
- 24-frame decoded cache at 112px has roughly 1.2MiB RGBA data plus overhead; verify device iPhone7 and recycle on memory warnings if needed.


## R4 owner video risks and gate
- Owner declares the specific uploaded MP4 is self-created and requests its incorporation. The new resource is from this upload, not the referenced third-party repository.
- Source has a white/off-white backdrop which remains intact. Dark mode will show a pale rectangle unless later owner-approved alpha-keying is performed; preserving the complete source has priority in this round.
- AVPlayerLooper and AVPlayerLayer are supported APIs but runtime iOS15 compilation, battery/thermal, loop gap and aspect rendering are not yet tested.
- The MP4 asset is NOT committed to GitHub. The agent's Inbox-only permission lacks an MP4 binary grant and direct product-resource write permission; no workaround by disguised bytes or extension.
- PR #159 and other GameLobby edits still need Governor conflict arbitration before applying to main.
