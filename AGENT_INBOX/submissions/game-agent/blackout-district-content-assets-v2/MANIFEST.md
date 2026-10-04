# Submission Manifest

- agent_id: game-agent
- task_id: blackout-district-content-assets-v2
- status: DROPPED
- base_main_sha: 41ebd5728e72683fd035c48e1fe5ea194f78a086
- asset_grant: VEILLINK-ASSET-GAME-001
- supersedes: blackout-district-realtime-v1 / Draft PR #30
- scope: Blackout District V2 expanded grid, compatibility hardening and direct governed CC0 city/model assets.
- proposed_files: VeilLink/Core/BlackoutDistrictGame.swift; VeilLink/UI/BlackoutDistrictScene.swift; VeilLink/UI/BlackoutDistrictLabView.swift; VeilLinkTests/BlackoutDistrictGameTests.swift; VeilLink/ThirdParty/ShaderKit/ShaderKitExtensions.swift; VeilLink/Resources/ThirdParty/ShaderKit/SHKDynamicGrayNoise.fsh; VeilLink/Resources/ThirdParty/ShaderKit/SHKRadialGradient.fsh; VeilLink/Resources/ThirdParty/ShaderKit/LICENSE.txt
- assets: ASSETS/blackout_kenney_service_truck.glb; ASSETS/blackout_kenney_road_straight.glb; ASSETS/blackout_kenney_traffic_light.glb
- protected_surfaces: none
- known_overlaps: shared future Game Lab navigation/render policy remains Governor-owned

## V2 delta

- grid expanded from 9 to 12 nodes and >130 building units;
- new East Station interchange, Emergency Command and Riverside Commercial districts;
- four critical facilities;
- safe ShaderKit fallback instead of fatal bundle lookup;
- fallback generated radial glow;
- Reduce Motion support;
- large-screen/iPad camera scaling;
- direct CC0 Kenney vehicle/road/traffic-light model sources staged under ASSETS/.
