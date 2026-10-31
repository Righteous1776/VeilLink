# Monogatari R5 exact missing-file checklist

Current main Build62 contains no upstream Monogatari 2.8.0 binary, engine resources, native WebKit host integration or VNPort vendor assembly.

Review upstream and prior Agent evidence:
- Game Agent PR #80: https://github.com/Righteous1776/VeilLink/pull/80
  - official upstream Monogatari `v2.8.0` ZIP size `2,798,775 bytes`
  - expected SHA-256 `16d221485888b0193312e9989ecafa57cb1913978bf2f09ba554552ba3885806`
  - upstream tag commit `89045f59b6af1669eefcd74ec59de0df52106bf1`
  - built JS engine git blob `0211c2f2c9adc56e28d5583feb0dd46b902d37d5`
- Game Agent PR #85: https://github.com/Righteous1776/VeilLink/pull/85
  - prior local R5 ZIP `VeilLink_Monogatari_Playability_R5_20261025.zip`
  - previously reported SHA256 `068ba55bfa36672d61960240a684dc4d90ceb7a10868409baf73bc4e6ac6c6f1`
  - prior R5 ZIP was 5,697,469 bytes; not committed to repo or included in this request
  - GitHub has text overlays `main-r5.js`, `veillink-native.js`, `veillink-ios15-compat.js`, `VeilMonogatariByteRange.swift`, but not the complete integrated native host or vendor engine.

Recovery sequence: retrieve actual official tagged ZIP from verified upstream; checksum byte-for-byte; inspect original licenses, full tree 12/12 asset hashes; recover R5 host from owner archive or rewrite using reviewed overlays; test WebKit local path/bundle preflight + script-startup failure + save/restore + iOS15; only then enable actual launch in GameLobby. Current recovered button is explanatory landing page with built-in Story Lab fallback, **NOT playable Galgame**. No binary artifacts or unlicensed vendor files put into Inbox.
