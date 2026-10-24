# Submission Manifest

- agent_id: game-agent
- task_id: blackout-district-realtime-v1
- status: DROPPED
- base_main_sha: 97b1da6ffa0a1b3a7c61a4f725ae67c1375492a4
- scope: Additive real-time 2D urban grid-repair game with deterministic blackout cascade simulation, realtime service-truck driving, storm/puddle handling, per-district building-light restoration, SpriteKit/CoreImage rendering, direct MIT ShaderKit vendoring, and approved CC0 Kenney city-asset intake.
- proposed_product_files:
  - VeilLink/Core/BlackoutDistrictGame.swift
  - VeilLink/UI/BlackoutDistrictScene.swift
  - VeilLink/UI/BlackoutDistrictLabView.swift
  - VeilLinkTests/BlackoutDistrictGameTests.swift
  - VeilLink/ThirdParty/ShaderKit/ShaderKitExtensions.swift
  - VeilLink/Resources/ThirdParty/ShaderKit/SHKDynamicGrayNoise.fsh
  - VeilLink/Resources/ThirdParty/ShaderKit/SHKRadialGradient.fsh
  - VeilLink/Resources/ThirdParty/ShaderKit/LICENSE.txt
- protected_surfaces: none
- direct_runtime_package_dependency: none
- third_party_code: twostraws/ShaderKit @ 07c974dc0cb48a935e0f131e12c0453e6082fa68, MIT
- third_party_binary_assets: Kenney CC0 packs approved for direct product use, but not committed into Inbox because governance forbids binary/large-artifact drops
- performance_policy: preserve iOS 15 source compatibility; iPhone 7 performance is not a design ceiling
- known_overlap: no direct BlackoutDistrict file/symbol overlap found on current main at preparation time

## Owner authorization

Repository owner explicitly authorized direct reuse of third-party open-source assets/code for the game lane to reduce duplicated work and iteration cost.

This authorization does not constitute a LIVE-LANE-GRANT; the submission remains INBOX_ONLY.
