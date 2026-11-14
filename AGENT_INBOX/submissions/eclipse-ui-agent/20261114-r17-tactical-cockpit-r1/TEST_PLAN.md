## Reproduction
`swiftc -frontend -parse FILES/VeilLink/UI/*.swift FILES/VeilLink/Agent/Games/*.swift`
`swiftc -swift-version 6 -warnings-as-errors -O TESTS/MiniGameTypes.swift TESTS/VeilEclipseThreatReadout.swift TESTS/main.swift -o /tmp/r17-check && /tmp/r17-check`
`git apply --check R17_ADVISORY.patch` from the documented hybrid baseline.
No project-level iOS compile in the current environment.
