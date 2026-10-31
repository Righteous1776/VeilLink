# Risks — board side selection R1

- The candidate depends on Draft PR #114 and does not apply verbatim to current `main`; stack arbitration is mandatory.
- Changing side intentionally restarts the current board. Existing restart semantics record an unfinished local line; it does not clear any archive.
- A physical-side swap must keep learning roles semantically stable; the candidate's `learningActor` mapping is the protected compatibility boundary.
- Real PVS/VCF and Xiangqi second-side execution, dynamic type, VoiceOver and iPhone 7 interaction remain untested.
- No default engine, formation policy, storage schema or player data is changed.
