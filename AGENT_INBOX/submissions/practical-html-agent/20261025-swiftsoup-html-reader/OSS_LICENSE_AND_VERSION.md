# SwiftSoup third-party OSS provenance

Repository: https://github.com/scinfu/SwiftSoup

Selected tag: `2.9.6` (released July 19, 2025).
Selected manifest URL: https://github.com/scinfu/SwiftSoup/blob/2.9.6/Package.swift
Manifest inspected from GitHub connector in current session:

```
 // swift-tools-version:5.9
 name: "SwiftSoup"
 platforms: iOS 13+, macOS 10.15+, watchOS 6+
 product: library "SwiftSoup"
 dependencies: none
```

Official license: MIT, upstream `LICENSE` (jsoup copyright 2009–2025 Jonathan Hedley; Swift port copyright 2016–2025 Nabil Chatbi). As MIT requires, ship the full original license and attribution with any distribution that includes the library.

Latest inspected release: `2.14.3`, Oct 16 2026 — Swift tools 6.0, **not compatible with current Build61 Swift tools 5.9 without toolchain migration**. Tags 2.10.3 and 2.11.2 also require 6.0. Do not allow floating dependency versions.

Source inspection: upstream 2.9.6 README demonstrates `SwiftSoup.parse`, `document.title()`, `document.select(...)`, `element.text()`, `element.attr("href")`; 2.9.6 implementation confirms `Document.body()` and `Elements.remove()`.

No third-party code, data set or assets copied into this Inbox. It stages original integration code and a dependency pin proposal only. Verify licensing and binary redistribution notices before release.
