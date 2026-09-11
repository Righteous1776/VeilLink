# VeilLink

VeilLink is a GitHub-buildable iOS 15+ prototype for nearby, serverless encrypted
messaging over Bluetooth Low Energy. The UI is Chinese-first and adapts separately
to compact iPhone screens and regular-width iPad layouts.

## Included in V0.1

- SwiftUI phone tab layout and iPad sidebar/detail layout.
- Up to five local cryptographic identities.
- Six-digit app lock with Touch ID / Face ID fallback.
- CoreBluetooth central + peripheral discovery and state restoration.
- Signed identity hello, ephemeral X25519 handshake and six-digit verification.
- ChaCha20-Poly1305 encrypted text packets with replay counters.
- Fragmented BLE GATT transport with flow-aware queues and JPEG transfer.
- SQLite WAL storage with encrypted message bodies.
- Password-encrypted ZIP backup and rollback-first restore path.
- Hidden black-and-gold Owner Mode with expiring, privacy-bounded capabilities.
- GitHub Actions workflows for simulator compilation and unsigned IPA packaging.

Resumable attachment checkpoints, multi-hop relay, signed Owner token generation,
and full on-device BLE testing remain for the next
iteration. Their boundaries are already represented in the architecture.

## Build entirely on GitHub

1. Create an empty GitHub repository and upload this project.
2. Keep the default branch named `main`.
3. Open **Actions → iOS CI → Run workflow**.
4. The workflow installs XcodeGen, generates `VeilLink.xcodeproj`, resolves the
   package dependency, and compiles against an iOS simulator SDK.
5. Run **Build unsigned IPA** to receive `VeilLink-unsigned.ipa` as an artifact.

The unsigned IPA verifies device compilation but cannot be installed directly on a
normal iPhone. Installation requires an Apple-issued development/distribution
certificate and matching provisioning profile. Never commit certificate, profile,
or private-key files to GitHub; the repository ignores their common extensions.

## Local Mac build, if available later

```sh
brew install xcodegen
xcodegen generate
open VeilLink.xcodeproj
```

## Security status

This is an engineering prototype, not an independently audited cryptographic
product. Do not represent V0.1 as suitable for high-risk communications until the
protocol, key lifecycle, restore path and real-device BLE behavior have been tested
and reviewed.

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the protocol boundaries.
