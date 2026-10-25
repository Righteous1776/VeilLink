# TEST PLAN
1. Run `python3 verify_monogatari_vendor.py --release-zip /trusted/monogatari-v2.8.0.zip`, require VERIFIED_OFFICIAL_BYTES.
2. Check intentional single-byte corruption, wrong size, duplicated ZIP name, traversal/symlink and missing file all fail closed.
3. Run same script `--extract /new/nonexistent/VisualNovelBundle`; verify official entire tree, compiled browser engine and license.
4. Apply owner-provided R1 WebKit glue and story overlays to *separate* integration branch only after Inbox Governor approval.
5. Check XcodeGen Copy Bundle Resources: full relative engine/css/js assets are preserved.
6. Full macOS iOS15 simulator XCTest plus real iPhone7 iOS15.8.3 offline launch, taps, saving/restore, appearance transitions, memory and media.
7. Gate on #64/#65/#66 P0 repairs; no IPA Action, release or main merge as part of this Inbox PR.
