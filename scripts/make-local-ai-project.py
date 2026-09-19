#!/usr/bin/env python3
from pathlib import Path

source = Path("project.yml")
destination = Path("project.local-ai.yml")
text = source.read_text()

settings_anchor = """settings:
  base:
    SWIFT_VERSION: 5.9
"""
settings_replacement = """settings:
  base:
    SWIFT_VERSION: 5.9
    SWIFT_ACTIVE_COMPILATION_CONDITIONS: "$(inherited) REAL_LOCAL_AI_REQUIRED"
"""
if text.count(settings_anchor) != 1:
    raise SystemExit(f"project settings anchor mismatch: {text.count(settings_anchor)}")
text = text.replace(settings_anchor, settings_replacement, 1)

source_anchor = """    sources:\n      - path: VeilLink\n    dependencies:\n"""
source_replacement = """    sources:\n      - path: VeilLink\n        excludes:\n          - Resources/Qwen3-0.6B-Q4_0.gguf\n      - path: VeilLink/Resources/Qwen3-0.6B-Q4_0.gguf\n        buildPhase: resources\n    dependencies:\n"""
if text.count(source_anchor) != 1:
    raise SystemExit(f"project source anchor mismatch: {text.count(source_anchor)}")
text = text.replace(source_anchor, source_replacement, 1)

dep_anchor = """      - sdk: libsqlite3.tbd\n      - package: ZIPFoundation\n"""
dep_replacement = """      - sdk: libsqlite3.tbd\n      - package: ZIPFoundation\n      - framework: Vendor/llama.xcframework\n        embed: true\n"""
if text.count(dep_anchor) != 1:
    raise SystemExit(f"project dependency anchor mismatch: {text.count(dep_anchor)}")
text = text.replace(dep_anchor, dep_replacement, 1)

destination.write_text(text)
print(destination)
