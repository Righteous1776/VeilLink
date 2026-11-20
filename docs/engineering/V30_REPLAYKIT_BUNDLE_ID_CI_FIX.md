# V30 ReplayKit target embedded binary failure — root cause and fix

Existing PR #245 Actions run #44746008189, exact head c5fa3a5, reached
the iOS Simulator embedded-binary validation after Swift sources compiled.
The failure was:

    Embedded binary's bundle identifier is not prefixed with the parent app's bundle identifier.
    Embedded Binary Bundle Identifier: (null)
    Parent App Bundle Identifier: studio.zeo.veillink

The target PRODUCT_BUNDLE_IDENTIFIER in project.yml was already correct:
studio.zeo.veillink.screenshare. Its dedicated Info.plist omitted the
CFBundleIdentifier key, so Xcode's embedded validation observed null.

Fix in this independent staging branch:
- Add CFBundleIdentifier = $(PRODUCT_BUNDLE_IDENTIFIER) to BroadcastUpload Info.plist.
- Add CFBundleExecutable = $(EXECUTABLE_NAME) and InfoDictionaryVersion.
- Offline V30 preflight checks these keys and broadcast-services-upload point.
- The compiled .appex release gate checks actual identifier and executable.

This is a SOURCE fix, not a proof of a successful subsequent build.
No additional GitHub Actions were dispatched while preparing it.

Other V30 release gates (signed App Group, encryption, iPhone-to-iPhone
ReplayKit and capture stop) remain mandatory.
