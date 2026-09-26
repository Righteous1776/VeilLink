# VeilLink LEGAL_CONSENT_GATE_V1

- Gate is evaluated before `AppModel` initialization.
- No SQLite, identity manager, BLE, LAN, Internet Relay, Mesh, community or background communication model is created until the current release agreement is accepted.
- Acceptance is bound to legal document version, CFBundleShortVersionString, CFBundleVersion, SHA-256 of canonical text and acceptance time.
- Record and HMAC are stored in Keychain; a device-local 256-bit HMAC key is also Keychain-protected.
- Any app version/build/document change invalidates prior acceptance.
- Intentional crashes and `exit(0)` are explicitly prohibited as gating mechanisms.
- Declining consent leaves the app locked. Automatic data deletion is prohibited. A future "erase local data" action must require a distinct destructive confirmation.
- iOS system permission dialogs remain authoritative. The in-app authorization notice does not replace system permission APIs.
- Legal text deliberately does not attempt to waive liability that applicable law does not allow to be waived.
