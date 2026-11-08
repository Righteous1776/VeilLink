# VLP-CODEX-P5-001 — explicit Owner scope extension

Live baseline main: 2c5b5161027edff097b27fe3323d30f6ca3e430e.
Development baseline: bcf683fca83ffcb671be18c25beaefe20909a901.

Owner explicitly approved in this task conversation:
“授权在 dev/veilopoly 修改大富翁模块、VeilLink 大厅／宿主联机桥接及对应测试，
并覆盖原 P5 限制；仍不改底层通信、Wire v4、身份或数据库，不合并 main、不发布 IPA。”

This supersedes only the earlier P5/write-path exclusion in #168. It does not
grant release, workflow dispatch, version, identity, security or DB/schema edits.
Existing governance/authority registries are not edited by this receipt.

Bounded implementation: module Net/UI/Persistence, new host bridge and lobby
section, minimal AppModel callback hookup, corresponding tests. Reuse existing
SessionCoordinator.sendControlEvent/enqueueReliableControlEvent and authenticated
onControlEventReceived; no SessionCoordinator/VeilControlEvent/Wire/transport edit.

First topology is explicitly 2 phones / 2 human seats + 2 existing AI seats.
No four-phone support, host migration or live device acceptance is implied.
All financial activity remains fictional, nonredeemable game currency.

Apple SDK, simulator and actual two-phone testing are NOT_RUN in this Linux
environment. Portable state/transport tests and actual host source hookup must
be reported separately from verified device connectivity.
