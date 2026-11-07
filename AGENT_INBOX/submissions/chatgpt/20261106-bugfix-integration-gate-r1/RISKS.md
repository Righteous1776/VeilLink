# Risks and containment
- Integration branch **NOT CREATED**; this Inbox draft only proposes a safe order. Do not mark patches APPLIED.
- 5 exact hunk intersections require human/automated governor conflict arbitration; 9 file overlaps include additional semantic risk.
- #138/#147 alter same image/file policy lines, #140/#147 same import error and copy entry; using git "ours/theirs" may silently remove safety.
- #137/#146 touch BLETransport: headphones and CoreBluetooth share system-controlled radio; no guarantees of independent 5 Bluetooth pipelines.
- #145 full DB integrity check off-main could block DatabaseStore serialized queue under heavy work; measure before shipping.
- #141 self-play export serializes full history and may stall large archives.
- #147 is file import safety only, NOT generic peer transfer; do not market PDF/ZIP sending as available.
- No authority to self-merge or bypass protected surfaces; no actual Xcode or device tests performed.
