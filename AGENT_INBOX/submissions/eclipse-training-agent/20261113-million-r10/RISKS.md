# Risks and overlap

- Main currently contains no ECLIPSE unified kernel; this proposal depends on Governor arbitration and integration of PR193, not merely importing a new training file.
- Overlaps PR193/#196 independent/unified kernel, #186/#187 learning/safety,
  #199/V9 and #206/V10 tactical search; #197/#198/#200/#203/#204 ECLIPSE UI.
  Their branches and submissions were not modified. This package does not merge
  those proposals or claim they are integrated.
- Training alternatives are rule-labeled counterfactuals from genuine boards.
  They are not historical actual moves, independent human games or million
  native self-play games. Repeated histories and D4 transforms are not counted
  as independent novel records.
- Teacher utility is limited tactical supervision; prediction accuracy is not Elo.
  Only an arena can support an improvement claim, scoped to its budgets/opponent.
- Existing kernel root safety scans happen before the search-budget gate;
  actual latency can exceed configured milliseconds. Report observed latency.
- Full master/V9/V10 strength, third-party engine comparison, iOS XCTest,
  real-device performance/thermals and installation are unverified until run.
- Never expose live candidates, principal variations or tactical hints in ECLIPSE
  UI. No UI behavior or telemetry firewall is changed by this package.
- Raw owner archives and training arrays remain local. No binary model, private
  history, executable, toolchain, build output or opaque archive enters Inbox.
- Existing opt-in external JS path does not consume this model; only the proposed
  ECLIPSE native unified path does. Do not advertise JS as trained.
