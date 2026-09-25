# Experimental AI preservation contract — V0.10.2 R4

R4 isolates experimental AI code from the default Core Xcode target. It **does not delete, move, rewrite, or rename** the historical AI source/resource tree.

Preserved in-place for research, rollback and later experimental builds:

- `VeilLink/Agent/MaleCNS/**`
- `VeilLink/Agent/Games/TrainedGamePolicyRuntime.swift`
- `VeilLink/Agent/Games/MaleCNSGameDecisionEncoder.swift`
- llama/Qwen implementation files under `VeilLink/Agent/Language/`
- VFLY / MaleCNS model resources under `VeilLink/Resources/`
- `VeilLink/Resources/AgentModels/game_policy_ranker_v4.*`
- `Tools/AgentTraining/**`
- `Tools/VeilFlyBuilder/**`
- historical checkpoint/docs already present in the repository

The default Core target excludes those implementation paths. `scripts/make-local-ai-project.py` reconstructs an Experimental AI XcodeGen project that re-includes the preserved source/test tree and adds the llama framework/model path.

`verify-core-source-isolation.py --write-manifest docs/EXPERIMENTAL_AI_PRESERVATION_V0102.json` records SHA-256 and byte counts for the preserved files. The manifest is evidence only; it is not a migration format and does not replace the original files.
