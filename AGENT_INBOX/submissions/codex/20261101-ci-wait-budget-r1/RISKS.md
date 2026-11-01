# Risks

- The eight-second bound can make a genuine stall take longer to report, but avoids scheduler-dependent false failures and matches the existing NativeGameBroker convention.
- Linux cannot claim an Xcode XCTest pass; required Apple CI execution remains pending.
- This candidate overlaps any independently proposed edit to `AgentControlAndLocalGameTests`; the Governor must choose one wait-policy patch.
