# R5 engineering risks / conflicts

- **Current status**: only proposal files have been staged in GitHub Inbox. No product changes, no old-engine deletion, no new IPA, no on-device verification.
- **Overlap**: active Draft PR #186 R2 tactical guard; #187 Thinking Studio UI; #190 experimental Swift kernel provenance. Do not merge R5 blindly or drop their data-protection / force-block fixes.
- **Strength**: 1696/1696 proves agreement with a historical fork-safety oracle on 212 correlated positions; it does NOT establish superiority in independent games. Positional scoring and root preference may need tuning.
- **Soundness**: limited VCF checker is conservative and budgets proof time to 30%; absence of proof is not proof of absence. A full VCT is not implemented; no unverified 'forced win' message permitted.
- **Performance**: Swift/Linux timings do not predict iOS hardware. Candidate generation and O(15x15x5) evaluation need future profiling and incremental optimization.
- **Licensing**: Original third-party JS in current app is MIT and remains attributable while shipped. Fresh independent code must be reviewed for copy-free implementation before removing obsolete package notices. Don't pretend simply renaming copies removes obligations.
- **Storage**: never overwrite local training, export package, key or user history. No source exports or opaque archives enter public GitHub branch.
- **Governance**: INBOX_ONLY. No direct changes to source tree, release, project.yml, CI or protected settings; no self-merge.
