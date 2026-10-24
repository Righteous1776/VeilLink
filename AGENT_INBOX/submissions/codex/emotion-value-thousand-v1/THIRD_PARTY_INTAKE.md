# Third-party source intake — emotion-value program

## Rule

The owner has authorized use of third-party open source and databases, but that is not blanket permission to copy content. Every intake must record source URL, commit/tag, license text, attribution requirements, file list, SHA-256, privacy review, iOS 15 impact and removal path before it enters the product or an Asset Drop.

## Read-only candidates inspected on 2026-10-25

| Source | Remote license metadata | Potential use | This submission |
|---|---|---|---|
| `muan/emojilib` | MIT | locally searchable emoji keywords / emotional visual vocabulary | **Not imported**; review exact commit and bundled license before code use |
| `googlefonts/noto-emoji` | OFL-1.1 | emoji font/art fallback | **Not imported**; assets require an Asset Drop grant, attribution review, size budget and accessibility review |
| `unicode-org/cldr` | GitHub reports `NOASSERTION` | locale-aware labels and plural/date data | **Not imported**; requires direct license/legal review before any copying |

## Rejected by default

- copyrighted quote, lyric, fiction, character, therapy-script, music or image databases without a compatible explicit license;
- non-commercial, no-derivatives, unclear-scraping, attribution-unfulfillable or personal-data corpora;
- analytics/advertising SDKs, remote “mood scoring”, silent account creation, or data brokers;
- binaries, archives and model weights outside an active Asset Drop grant.

## First-wave provenance

`VeilEmotionGardenEngine.swift` contains original short prompts authored for this proposal. No third-party code, asset, quote corpus or user data is copied into this submission.

