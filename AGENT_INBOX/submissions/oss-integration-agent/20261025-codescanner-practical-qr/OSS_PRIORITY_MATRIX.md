# Practical third-party shortlist — evidence-based, avoid random dependency growth

| Priority | Third-party / official URL | License / constraints | Real VeilLink user-facing payoff | Decision |
| --- | --- | --- | --- | --- |
| P1 | twostraws/CodeScanner https://github.com/twostraws/CodeScanner (2.5.2) | MIT; tag Package.swift: tools 5.9, iOS13+, 0 deps | live camera QR for remote handshake and offline text QR | **proposed now**, exact version lock |
| P2 | guoyingtao/Mantis-spm https://github.com/guoyingtao/Mantis-spm (consider 3.1.x) | MIT; upstream Mantis iOS15, Xcode13+; confirm SPM release before lock | crop/rotate/straighten photo locally *before* encrypted upload to save BLE bytes | next separate lane, must touch-test on iPhone7 |
| P2 | scinfu/SwiftSoup https://github.com/scinfu/SwiftSoup | MIT; verify fixed Swift5.9-compatible release | import HTML article from Files, strip scripts, offline reading/quote extraction | only after explicit local file picker UX and max-byte parser budget |
| P3 | gonzalezreal/swift-markdown-ui https://github.com/gonzalezreal/swift-markdown-ui | MIT; iOS15 but many tables/multiimage features require iOS16; upstream in maintenance mode | render markdown in local message notes | defer until iOS15 fallback demonstrated |
| P3 | kean/Nuke https://github.com/kean/Nuke (12.x) | MIT; Nuke 12 Swift5.7/Xcode15/iOS13; Nuke13 requires Swift6.2/Xcode26 | cached image thumbnails | defer: VeilLink already uses ImageIO downsample/NSCache |
| REJECT new | onevcat/Kingfisher https://github.com/onevcat/Kingfisher latest | MIT; latest source requires Xcode26/Swift6.2 | web image cache largely duplicates existing local cache | do not import current release |
| REJECT migration | GRDB.swift https://github.com/groue/GRDB.swift | MIT; latest toolchain constraints and schema/auth boundary | richer SQLite queries | do not replace existing encrypted SQLite until data-preserving migration verified |
| EXISTING | weichsel/ZIPFoundation https://github.com/weichsel/ZIPFoundation | MIT; already in project.yml | ZIP backup/restore | reuse; do not count as new dependency |
| Alternative P2 | TimOliver/TOCropViewController https://github.com/TimOliver/TOCropViewController | MIT; UIKit-based image crop library | crop photo | choose **one** crop library, not Mantis plus TOCrop |

**Security and provenance:** MIT is permissive, not public domain. Preserve copyright/NOTICE and lock exact reviewed commit/tag. Fetch dependencies from official GitHub only. Do not blindly copy repositories, prebuilt IPAs, datasets, binary models or opaque assets. Prefer native AVFoundation/Vision/PhotosUI when equivalent behavior exists. Existing camera permission is shared: full app needs explicit local QR description.

**Compatibility gates:** main deployment iOS15, `SWIFT_VERSION: 5.9`, iPhone7 A10, strict-concurrency complete. Avoid iOS16-only APIs, Swift6.2-only latest packages, heavyweight rendering and UI gesture overlays while touch P0 open.
