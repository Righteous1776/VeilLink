# Proposal — replace short AI-result wait budgets

The baseline scan found two asynchronous outcome polls below five seconds in `AgentControlAndLocalGameTests`: local Gomoku used two seconds and the tactical AI activation used three seconds. They poll every 40ms and fail only after their deadline, so overloaded macOS CI can produce a false failure.

The patch changes both deadlines to the established eight-second bounded budget already used by `NativeGameBrokerTests`. Polling remains 40ms and failure assertions remain intact.

The 80ms inference cancellation delay and 450ms stale-task observation are not presented as completion waits: they deliberately create cancellation ordering and are left unchanged in this narrowly scoped proposal.
