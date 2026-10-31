# Risks — CI release governance

## Protected surfaces
This proposal touches `.github/workflows/core-release.yml` in PATCH.diff only. No lane authority to apply it to product or release workflows. Governor approval required.

## Cross-agent overlap
Workflow is reused by `unsigned-ipa.yml` and `dual-platform-release.yml`. New `publish_release` input defaults false to preserve packaging-only calls, but carefully evaluate all callers. Draft #96/#99/#100 and any other integrations must be reviewed for release gating changes.

## Behavioral risks
Manual explicit opt-in reduces accidental publication but does not replace authenticated Owner approval, branch protection, required reviewers or device acceptance. Dispatch may be performed by users with repository workflow permissions; a protected environment review is a separate control.

## Migration / compatibility risks
Existing immutable release tags/assets remain unchanged. No application data migrations, new signatures or IPA rewrite.

## Performance / battery risks
No runtime footprint. Workflow job execution unaffected until publish step.

## Security / privacy risks
Unaudited automatic public release of an unsigned, unverified IPA is the primary governance concern. Requiring explicit opt-in is fail-closed, but requires testing of all reusable callers.

## Rollback
Governor reverts only this workflow patch after review if it disrupts legitimate release path; do not retroactively change or overwrite published immutable release assets.
