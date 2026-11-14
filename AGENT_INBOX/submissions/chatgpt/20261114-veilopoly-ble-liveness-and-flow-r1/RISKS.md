# Risks, conflicts and governor decisions

- Protected files: shared `BLETransport.swift`, Veilopoly game bridge, package net policy; explicit Integration Governor review required.
- Overlap: PR #201 (BLE reconnect/foreground), PR #184 (Veilopoly UI/rules), PR #188 (Veilopoly presentation), any newer integration touching BLETransport/Veilopoly. Compare current integrated main first; do not overwrite another agent's candidate.
- A healthy CoreBluetooth PHY is not necessarily a functional GATT or end-to-end E2EE channel. The proposed status distinction deliberately avoids claiming data-ready from PHY alone.
- In-place retry may consume more energy on a truly wedged PHY. Measure retry cadence and keep manual recovery available; consider a separately approved bounded failover if physical hardware tests show a permanent hung state.
- Retaining queued fragments can increase memory use up to existing BLE admission caps. Never raise queue limits without separate tests.
- Critical send loss must still pause host/guest actions to prevent divergence; owner request never licenses pretending lost state changes were delivered.
- No macOS/Xcode/iOS SDK device harness was executed here. Inbox staging is not a shipping fix and no IPA build/release authorized.
