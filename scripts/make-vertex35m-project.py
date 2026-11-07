#!/usr/bin/env python3
"""Create a separate native iOS spec for Vertex 35M; leave standard project unchanged."""
from pathlib import Path

source = Path("project.yml")
output = Path("project.vertex35m.yml")
text = source.read_text(encoding="utf-8")

anchor = "    SWIFT_VERSION: 5.9\n"
assert text.count(anchor) == 1, "SWIFT_VERSION anchor changed"
text = text.replace(anchor, anchor + '    SWIFT_ACTIVE_COMPILATION_CONDITIONS: "$(inherited) REAL_LOCAL_AI_REQUIRED VERTEX_CHAT_ONLY"\n', 1)

# Restore only llama engine; NOT the old global Qwen runtime or model catalog.
for name in ("LlamaInferenceEngine.swift", "LlamaRuntimeConfiguration.swift", "LlamaCancellationGate.swift"):
    excluded = f"          - Agent/Language/{name}\n"
    assert text.count(excluded) == 1, f"Missing exclusion {name}"
    text = text.replace(excluded, "", 1)

# Standard source tree continues excluding the model so resource is single-copy.
model_excluded = "          - Resources/LocalAI/Vertex-0.6-35M-Instruct-Q4_K_M.gguf\n"
assert text.count(model_excluded) == 1
resource_anchor = "      - path: VeilLink/Resources/GomokuEngineV2\n        type: folder\n        buildPhase: resources\n"
assert text.count(resource_anchor) == 1
text = text.replace(resource_anchor, resource_anchor +
                    "      - path: VeilLink/Resources/LocalAI/Vertex-0.6-35M-Instruct-Q4_K_M.gguf\n"
                    "        buildPhase: resources\n", 1)

dependency = "      - sdk: libsqlite3.tbd\n"
assert text.count(dependency) == 1
text = text.replace(dependency, dependency + "      - framework: Vendor/llama.xcframework\n        embed: true\n", 1)

output.write_text(text, encoding="utf-8")
print(f"VERTEX35M_PROJECT_READY={output}")
