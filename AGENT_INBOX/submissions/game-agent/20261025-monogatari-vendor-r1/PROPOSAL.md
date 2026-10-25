# PROPOSAL — Official Monogatari 2.8.0 binary intake
## Owner decision
The official runtime must be imported whole, not replaced with homemade interpretation code. Retain full upstream engine/ and its MIT attribution. Only host template and game-specific resources are adapted.
## Verified source
GitHub release asset pinned at exactly 2,798,775 bytes and SHA-256 `16d221485888b0193312e9989ecafa57cb1913978bf2f09ba554552ba3885806`; upstream tag commit `89045f59b6af1669eefcd74ec59de0df52106bf1`. Browser bundle Git blob `0211c2f2c9adc56e28d5583feb0dd46b902d37d5`.
## Deliverable in THIS PR
- VENDOR_LOCK.json: immutable origin, size, digest and tag anchors.
- FILES/Tools/VNPort/verify_monogatari_vendor.py: revalidates actual ZIP before optional safe pristine extraction.
- PATCH.diff: points to the proposed product-side paths, which must NOT be applied until an integration window.
## Not delivered in THIS PR
Official zip cannot be obtained through current ChatGPT execution runtime; no fake .zip or home-built substitute is checked in. Earlier R0 and current R1 code/Swift adapter are maintained in user-facing artifacts of the conversation, *not* in this Inbox PR.
## Governor intake
Download via network-enabled audited worker or import owner's exact upstream ZIP, run pinned script and verify output; stage original upstream as separate app resource directory under controlled integration branch; perform iOS15 XcodeGen, full XCTest and actual iPhone7 WebKit/saving/gesture tests. Do not trigger IPA/release merely to download the upstream ZIP.
