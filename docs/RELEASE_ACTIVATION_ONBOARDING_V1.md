# RELEASE_ACTIVATION_ONBOARDING_V1

Release-target local iteration layered after `LEGAL_CONSENT_GATE_V1` and ultimately based on validated iOS baseline `14955c9143f202ac1f19a37d78d88735da8bb0cb`.

## Product behavior

- First activation only: activation animation -> connectivity introduction -> trust/community introduction -> quick-start guide -> legal consent.
- Onboarding completion is stored in `UserDefaults` using schema `release-activation-v1`, so reinstall/local data reset can show it again while routine app updates do not replay it.
- Legal consent remains version/build/document-hash gated. Future releases can require the legal gate again without replaying the product tour.
- AppModel is still not created until both first activation and the current legal agreement are satisfied.
- Users can jump directly from informational pages to the agreement; they cannot skip the legal gate.

## Design system

- Native SwiftUI only; no WebView, React, Lottie or new animation dependency.
- Extends existing `VeilMotionPolicy`, `VeilPressStyle`, `VeilMorphIcon`, `VeilTheme` and render-profile degradation.
- Native vector Morphicons interpolate equal-topology paths.
- New-neumorphic plates use restrained dual shadows, metal edge highlights and physical press feedback.
- Page transitions animate transform/opacity only and honor Reduce Motion.
- Persistent decorative rotation/pulse is disabled by existing render policy on legacy/low-power/thermal-constrained paths.
- First-run explanatory animation is intentionally longer than normal UI motion; ordinary controls remain short and interruptible.

## iPhone 7 / iOS 15

- Deployment target remains iOS 15.
- No iOS 16+ animation API is required.
- Legacy compositor gets cheaper shadows and no continuous decorative animation.
- All pages are vertically scrollable on short displays.

## Release gate

Must still run real XcodeGen, simulator build/test, unsigned iPhoneOS Release and artifact verification before release-ready status.
