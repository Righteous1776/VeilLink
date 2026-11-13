# Verification gates
- Apply P0 patch to dev/veilopoly@afa5607 on an integration branch only; review touched paths. This Inbox submission has NOT run Xcode build/XCTest or two-device acceptance.
- Tap blank/same/different tile; no automatic game move. CardRevealGate cannot skip; 0.4s cooldown and 0.6s toast/Reduce Motion.
- Auction: four step controls and B01 hit zones >=44pt; long-hold 0.5s 10Hz, cash ceiling error haptic, under-minimum bid rejection, invalid states, slide/number-pad draft never auto-submits.
- Primary/destructive actions remain visible and accessible. NumericInput popover in iOS15 landscape, adaptive sheet behavior on compact environments.
- Panel title drag vs nested ScrollView. Unit tests for one-shot ACK and old save behavior. P2 camera acceptance separately.
