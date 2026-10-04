# Submission Manifest

- agent_id: game-agent
- task_id: rainline-content-assets-v2
- status: DROPPED
- base_main_sha: 41ebd5728e72683fd035c48e1fe5ea194f78a086
- asset_grant: VEILLINK-ASSET-GAME-001
- supersedes: rainline-last-train-realtime-v1 / Draft PR #28
- scope: Rainline V2 content, compatibility and governed third-party asset upgrade.
- proposed_files: VeilLink/Core/RainlineLastTrainGame.swift; VeilLink/UI/RainlineLastTrainScene.swift; VeilLink/UI/RainlineLastTrainLabView.swift; VeilLinkTests/RainlineLastTrainGameTests.swift; VeilLink/ThirdParty/ShaderKit/ShaderKitExtensions.swift; VeilLink/Resources/ThirdParty/ShaderKit/SHKDynamicGrayNoise.fsh; VeilLink/Resources/ThirdParty/ShaderKit/LICENSE.txt
- assets: ASSETS/rainline_kenney_train_diesel_a.glb; ASSETS/rainline_kenney_track_detailed.glb
- protected_surfaces: none
- known_overlaps: shared future Game Lab navigation/render policy remains Governor-owned
- source_prompt_summary: add real third-party assets, more gameplay content and compatibility without direct product-tree mutation.

## V2 delta

- four deterministic fault classes: lighting, traction, thermal and communications;
- differentiated system effects;
- expanded route story beats;
- Reduce Motion support;
- optional Kenney train-art aliases with procedural fallback;
- safe ShaderKit noise fallback;
- direct MIT ShaderKit source retained;
- direct CC0 Kenney Train Kit GLB assets staged under ASSETS/.
