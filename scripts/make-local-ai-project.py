#!/usr/bin/env python3
from pathlib import Path

source = Path("project.yml")
destination = Path("project.local-ai.yml")
text = source.read_text(encoding="utf-8")

settings_anchor = '''settings:
  base:
    SWIFT_VERSION: 5.9
'''
settings_replacement = '''settings:
  base:
    SWIFT_VERSION: 5.9
    SWIFT_ACTIVE_COMPILATION_CONDITIONS: "$(inherited) REAL_LOCAL_AI_REQUIRED EXPERIMENTAL_AI_RUNTIME"
'''
if text.count(settings_anchor) != 1:
    raise SystemExit(f"project settings anchor mismatch: {text.count(settings_anchor)}")
text = text.replace(settings_anchor, settings_replacement, 1)

core_sources = '''    sources:
      - path: VeilLink
        excludes:
          - Agent/MaleCNS
          - Agent/Games/TrainedGamePolicyRuntime.swift
          - Agent/Games/MaleCNSGameDecisionEncoder.swift
          - Agent/Language/LlamaInferenceEngine.swift
          - Agent/Language/LlamaLocalTextModelRuntime.swift
          - Agent/Language/LlamaRuntimeConfiguration.swift
          - Agent/Language/LlamaCancellationGate.swift
          - Agent/Language/LocalModelCatalog.swift
          - Agent/Language/LocalModelManager.swift
          - Resources/VeilFlyCore.vfly
          - Resources/VeilFlyLite.vfly
          - Resources/VeilFlyAssets.json
          - Resources/VFLYInstallationVerification.json
          - Resources/MaleCNSGameRankerCoreV1.json
          - Resources/MaleCNSGameRankerCoreV1.manifest.json
          - Resources/MaleCNSGameRankerLiteV1.json
          - Resources/MaleCNSGameRankerLiteV1.manifest.json
          - Resources/MaleCNSReadoutCoreV1.json
          - Resources/MaleCNSReadoutCoreV1.manifest.json
          - Resources/MaleCNSReadoutLiteV1.json
          - Resources/MaleCNSReadoutLiteV1.manifest.json
          - Resources/AgentModels/game_policy_ranker_v4.vlpol
          - Resources/AgentModels/game_policy_ranker_v4.manifest.json
          - Resources/LocalAI-THIRD-PARTY-NOTICES.txt
    dependencies:
'''
heavy_sources = '''    sources:
      - path: VeilLink
        excludes:
          - Resources/Qwen3-0.6B-Q4_0.gguf
      - path: VeilLink/Resources/Qwen3-0.6B-Q4_0.gguf
        buildPhase: resources
    dependencies:
'''
if text.count(core_sources) != 1:
    raise SystemExit(f"project Core source anchor mismatch: {text.count(core_sources)}")
text = text.replace(core_sources, heavy_sources, 1)

# test Core source anchor — Experimental build restores the preserved tests/fixtures too.
core_tests = '''    sources:
      - path: VeilLinkTests
        excludes:
          - MaleCNSNativeKernelTests.swift
          - MaleCNSNativeRolloutPoolTests.swift
          - MaleCNSVFLY1Tests.swift
          - LocalModelCatalogTests.swift
          - RealLocalInferenceSmokeTests.swift
          - Fixtures/MaleCNSFixture.vfly
          - Fixtures/MaleCNSFixture.vfly.manifest.json
    dependencies:
'''
heavy_tests = '''    sources:
      - path: VeilLinkTests
    dependencies:
'''
if text.count(core_tests) != 1:
    raise SystemExit(f"test Core source anchor mismatch: {text.count(core_tests)}")
text = text.replace(core_tests, heavy_tests, 1)

dep_anchor = '''      - sdk: libsqlite3.tbd
      - package: ZIPFoundation
'''
dep_replacement = '''      - sdk: libsqlite3.tbd
      - package: ZIPFoundation
      - framework: Vendor/llama.xcframework
        embed: true
'''
if text.count(dep_anchor) != 1:
    raise SystemExit(f"project dependency anchor mismatch: {text.count(dep_anchor)}")
text = text.replace(dep_anchor, dep_replacement, 1)

destination.write_text(text, encoding="utf-8")
print(destination)
