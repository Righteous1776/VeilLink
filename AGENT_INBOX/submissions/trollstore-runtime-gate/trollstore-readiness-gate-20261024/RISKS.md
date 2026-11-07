# Risks, threat model and coordination

1. A TrollStore marker is **untrusted installation evidence**, not a security principal. No feature can derive identity, user trust or E2EE authorization from it.
2. The gate is only an allow/deny advisory for app-owned plugins. Backends must re-enforce actual OS privileges and per-operation permission; `verifiedAvailable` evidence must originate in trusted local code.
3. More memory or background lifetime is not guaranteed by any source marker. No private entitlements, root helpers, sandbox escape, JIT or app-to-app surveillance are provided.
4. Ordinary/simulator/unknown variants always take standard route.
5. Probe TTL uses wall clock; treat it as a UX readiness cache, not a cryptographic time source. Backend must probe again on sensitive transition.
6. Thermal/low-power/legacy guards are conservative; additional performance validation on A9/A10 is required.
7. Overlap: PR #53 owns environment detection and Settings UI. Governor should integrate PR #53 first and wire the policy in a dedicated branch. PR #56 owns protocol/schema; this policy must never influence authenticated transport trust or database migration.
8. The optional capability toggle is not an entitlement grant or legal authorization; user controls and data boundaries must be enforced by the actual feature backend.
9. No production install claims, IPA, workflow dispatch or product-tree writes.
