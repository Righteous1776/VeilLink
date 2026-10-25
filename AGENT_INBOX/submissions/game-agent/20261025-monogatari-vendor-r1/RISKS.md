# RISKS — Gate enforcement
1. BLOCKER: official release ZIP actual bytes unavailable in this environment; no complete binary import yet.
2. Browser JS and styles are fingerprinted against upstream source tag, but asset ZIP verified only when file becomes available.
3. iOS 15 WKWebView: custom-scheme origin, localStorage/IndexedDB, CSP, media decode and service worker compatibility need device tests.
4. `project.yml` XcodeGen folder references may flatten nested resources; confirm `VisualNovelBundle/index.html` and engine/ structure inside .app.
5. Protect pre-consent, SQLite, Keychain, BLE, transport and existing chat settings; do not overwrite active P0 #64/#65/#66.
6. Full engine contents may include binary non-game icons and source maps; NEVER put binaries or ZIP inside Inbox; only controlled Governor integration resource tree.
7. Keep MIT license and inspect third-party redistribution notices.
