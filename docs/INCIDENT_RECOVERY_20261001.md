# VeilLink 26.9 cumulative recovery — 2026-10-01

## Incident

The I12 update package was applied as if it were a complete repository snapshot.
Its source base was the older V0.9.7 Build 41 tree, so the resulting `main` branch
contained the new I12/A10 work while silently deleting a large part of the formal
26.9 release. The succeeding GitHub Actions artifact name advertised a newer build,
but the source Info.plist still reported V0.9.7. A green packaging job therefore did
not prove that the cumulative product was intact.

## Recovery construction

- Recovery base: `4042281` (`r12-cumulative-validation`), the complete formal
  VeilLink 26.9 Build 53 line.
- Overlay: the I12/A10 changes introduced from `a56ce1a` through the last repair on
  the broken line, merged file by file instead of accepting its whole-tree state.
- Recovered identity: VeilLink 26.9 Build 54.
- No file from the 26.9 base is deleted by the recovery overlay.

The merge deliberately keeps voice/PTT, LAN transport, remote pairing, Tool Center,
background continuity and widget support, legal/onboarding, relay/community code,
the native game bots, and the complete formal test inventory. It also retains the
I12 collaborative stress tools, three-core plan, kernel runtime selector, A10 Ultra
M5 native bridge, trained compact resources, governance advisor, and shadow cognition.

## Safety decisions

1. A9 remains the stable primary path; A10 Ultra M5 remains
   `TRAINED_COGNITION_SHADOW` with `production_cutover: DENY`.
2. The compact A10 M5 resources are pinned by SHA-256 and their source-model
   provenance is checked in both source preflight and packaged IPA verification.
3. Raw `weights.npz`, `brain.npz`, `MaleCNSReference.vfly`, and the historical heavy
   AI assets are forbidden from the Core application payload.
4. App and widget versions inherit from `project.yml`; hardcoded source versions are
   rejected.
5. The IPA gate validates the packaged Info.plist semantically because Xcode/ditto
   may serialize it differently, while executable, asset catalog, tactical map, and
   A10 M5 resource content remain byte/hash verified.

## Permanent regression gates

`scripts/verify-recovery-lineage.py` fails if the repository loses either the 26.9
formal feature roots or the I12/A10 overlay, if the source/test inventory collapses,
if release identity regresses, or if a pinned A10 M5 resource changes unexpectedly.

`scripts/verify-core-release.py` independently checks the built `.app` and `.ipa`,
including version/build identity, unsigned state, launch-critical plist fields,
payload size, forbidden files, executable/resource parity, tactical map provenance,
and every compact A10 M5 resource hash.

Future update packages must be treated as overlays unless their manifest explicitly
proves that they are cumulative from the current checkpoint. A successful packaging
workflow alone must never be used as evidence that cumulative source history survived.
