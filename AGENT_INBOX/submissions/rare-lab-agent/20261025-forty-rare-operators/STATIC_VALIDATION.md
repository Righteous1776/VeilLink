# Static execution record

- Fresh GitHub main = 501ef814a0a9bea41419fe2d9f48315371b30320
- Swift Linux Foundation module compiled with Swift 6.2.1, SwiftPM `swift test -j 2`: eight XCTest methods passed 0 failures. One exhaustive method executed all 40 examples.
- UI syntax parse by `swiftc -frontend -parse` succeeded, no Apple SDK or SwiftUI type-check.
- Core source does not import SwiftUI/UIKit or reference app globals.
- One ToolCenter patch, three context lines.
- No iOS Actions, no IPA built, no main writes.
