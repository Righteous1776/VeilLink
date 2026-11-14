# Proposal

## Goal

Prevent a large image from entering an unreliable BLE path and add precise startup intervals before moving initialization work on speculation.

## Current problem

`ImageTranscoder` already runs detached and down-samples images, but its accepted output may be up to the Wire v4 ceiling of 3MB. A BLE link measured around 20–40KB/s can therefore spend many minutes transmitting/retrying a large image. Current startup events only bound `startup.begin` to `startup.success`; they do not identify whether app bootstrap or `AppModel` construction creates the owner-observed delay.

## Proposed behavior

- BLE and unknown future delivery routes are capped at 800KiB during image preparation. LAN and Internet Relay retain the existing 3MB limit.
- The cap is applied before an image is queued, with an accurate error that names the current-route ceiling.
- Wire v4's existing 3MB maximum remains unchanged; no frame, receiver, or schema change is made.
- Add `OSSignposter` intervals for `app.init`, `app.model_init`, and `app_model.init` so Instruments can distinguish launch stages.

## Architecture / implementation

`ImagePayloadPolicy` selects the cap from the existing `SessionCoordinator.preferredTransportKind(for:)`. Unknown routes use the BLE cap because a queued item may later travel by BLE. `ImageTranscoder.prepare` accepts a bounded maximum and applies it to preserved JPEG/HEIC/PNG and transcoded output. `ChatView` selects the cap before calling `sendImage`. Startup intervals are observational only and do not move, delete, or eagerly add initialization work.

## User-visible impact

BLE users receive a clear oversized-image error instead of silently queueing a 3MB image that can take many minutes. LAN/Relay image behavior stays within its existing 3MB limit. No startup UI behavior changes in this batch; it gains a measurable breakdown.

## Compatibility

Existing call sites retain the default 3MB `ImageTranscoder` behavior. The app message protocol, SQLite content records, supported MIME set, Relay semantics, and server compatibility are unchanged.

## Alternatives considered

- Rewriting the compression algorithm was rejected: Build64 already performs detached down-sampling and quality stepping.
- Changing Wire v4 or global attachment limits was rejected because it would alter a protected compatibility contract.
- Moving initialization onto arbitrary background tasks was rejected pending signpost evidence; many initialization steps establish data/security/UI state and cannot safely be guessed as deferrable.

## Acceptance criteria

- BLE/unknown policy returns exactly 800KiB; LAN/Relay returns the existing 3MB maximum.
- A prepared BLE image never reaches `sendImage` above the selected cap.
- `PATCH.diff` applies to Build64 with no whitespace error or deletion.
- Changed Swift files parse; the policy harness compiles and passes under strict concurrency.
- `OSSignposter` intervals are available to an iOS Instruments run when that environment becomes available; this is not claimed as executed here.
