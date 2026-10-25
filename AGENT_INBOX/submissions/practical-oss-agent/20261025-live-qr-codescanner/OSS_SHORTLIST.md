# Practical third-party OSS triage, 2026-10-25

| Source | Platform & license | Practical role in VeilLink | Decision |
|---|---|---|---|
| https://github.com/twostraws/CodeScanner tag 2.5.2 | MIT; Package.swift Swift-tools 5.9; iOS13+; no transitive packages | **Native camera scan** for remote QR pairing + standalone offline QR reader. Resolves verified gap in current source | **R1 staged as actual integration patch; not merged** |
| https://github.com/scinfu/SwiftSoup | MIT; pure Swift HTML parser; latest inspected release 2.13.9 | Open **user-imported local HTML** notes/bookmarks; strip active content, extract plain text and offline links, not network scraping | **P1 candidate; exact compiler / resource limits not yet certified** |
| https://github.com/gonzalezreal/swift-markdown-ui (MarkdownUI 2.x) | iOS15+ but tables/multi-image may require iOS16; upstream says maintenance mode | Readable local Markdown message/document preview with iPhone7 feature fallback | **P1 conditional; screen and minimum OS feature gate required** |
| https://github.com/apple/swift-collections tag 1.1.4 | Apache-2.0 with LLVM exception; Swift 5.7.2+ for 1.1.x, newer 1.2.x+ raise compiler floor | Ordered dictionary and deque for **diagnostic logs**, bounded outbox staging and UI event indexes without touching wire semantics | **P1 pinned 1.1.x only; benchmark / concurrency review** |
| https://github.com/weichsel/ZIPFoundation | Already declared in VeilLink `project.yml` from 0.9.19 | Strengthen existing **ZIP backup import/export verification**, not a new feature/library | **Reuse existing; protect legacy backup compatibility** |
| https://github.com/groue/GRDB.swift | Newer toolchain requirements may exceed current Swift5.9 Build61 | Database observation, indexed search and safer transactions | **DEFER**: SQLite v10, encryption and Keychain continuity unresolved; never auto-migrate |
| https://github.com/onevcat/Kingfisher | MIT; Swift image fetching/cache ecosystem | Image pipeline enhancements | **DEFER**: the app already has ImageIO downsampling + `ImagePreviewCache`; duplicating caches increases memory use on iPhone7 |

## Import requirements

Every library must be selected by exact tested version and exact upstream Git commit, with full license/NOTICE, transitive dependency tree, minimum iOS target, Swift 5.9 toolchain build, iPhone7 memory/touch profile, and security review. An external repository being open source does NOT authorize copying its unlicensed photos, datasets, fonts, user-generated media, passwords, or binary objects.

Only **CodeScanner** is proposed for package installation in this PR. No other dependency, third-party database, schema, network service or vendor source has been copied or installed.
