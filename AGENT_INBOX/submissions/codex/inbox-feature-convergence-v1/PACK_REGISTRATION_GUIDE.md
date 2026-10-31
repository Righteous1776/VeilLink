# Feature pack registration guide

## Pack contract

An accepted pack supplies:

1. Stable feature IDs and one `packID`.
2. User-facing title/subtitle/domain/keywords.
3. Resource class: featherweight, standard or render-heavy.
4. Required gates and permissions.
5. A conflict-group identifier when another proposal is mutually exclusive.
6. An integration-owned route resolver from ID to a lazily-created destination view.

Packs must not directly add dozens of cards or additional search boxes to `ToolCenterView`.

## Example descriptor

```swift
VeilFeatureDescriptor(
    id: "productivity.text-diff",
    packID: "productivity-wave-f1",
    title: "文本差异",
    subtitle: "逐行比较新增、删除与未变化内容",
    domain: .productivity,
    keywords: ["diff", "比较", "合并"],
    resourceClass: .featherweight,
    requiredGates: .releaseBaseline,
    conflictGroup: nil,
    isExperimental: false
)
```

## Launch policy

- Missing required gates fail closed and show the exact missing verification.
- Legacy devices, low-power mode and serious thermal pressure receive reduced rendering.
- Owner God Mode may force high-quality rendering, preserving the existing product requirement.
- Critical thermal pressure defers render-heavy features even in God Mode to prevent device damage or OS termination.
- Reduce Motion produces a static tier unless God Mode was explicitly selected.

## UI policy

- Render at most 30 rows per page and clamp any requested page to 100 items.
- Search uses pre-normalized text and domain indexes.
- A pack is instantiated only after the user taps an available entry; registry metadata must remain lightweight.
- Candidate or contract-only items are not shown as runnable product features.
