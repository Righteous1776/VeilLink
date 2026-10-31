# Risks

- Simply changing UI labels is unsafe: Build64 search and rule gates hardcode `.guest`.
- Existing learning code historically treats host as human and guest as AI. Physical colour switching must use a semantic role mapping, not migrate or reinterpret stored archives.
- Changing sides during an active search can produce a ghost move unless restart cancels the task before scheduling the new computer opening.
- PR #117 contains an older advisory version of the same feature; this R2 proposal supersedes it for Build64 and must not be applied twice.
- The change touches current Gomoku/Xiangqi controller and lobby surfaces already modified by the Build64 release. Governor must apply on latest main and rerun complete iOS gates.
- No claim of physical-device validation is made by this Inbox proposal.
