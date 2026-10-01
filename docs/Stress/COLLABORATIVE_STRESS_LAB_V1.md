# VeilLink Collaborative Stress Lab V1

## Purpose

Exercise real secure-session and BLE queue behavior between two VeilLink devices without contaminating normal chat/game history.

## Architecture

`trusted peer + Secure Session`

→ `VLSTRESS1 control frame over encryptedMessage`

→ `CollaborativeStressCoordinator`

→ text lane / bulk manifest / temporary Gomoku

Binary media-class stress:

`bulk manifest locally accepted`

→ peer replies `bulkReady` only after its stress accumulator exists

→ existing `attachmentChunk` encryption

→ BLE `.bulk` queue

→ in-memory stress accumulator

→ SHA-256 receipt

No normal `messages`, `outbound_queue`, attachment persistence or Conversation row is required for the temporary load.

## Synthetic data only

Text is deterministic synthetic ASCII. Image-class data is deterministic binary. Voice-class data is deterministic RIFF/WAV PCM-style data. Temporary game events are generated from local Gomoku state and passed through `MiniGameCodec`.

## Non-goals

- not a new user-facing chat channel;
- not a voice-message implementation;
- not automatic pairing;
- not a way to bypass host safety fuses;
- not a replacement for MetricKit / black-box / XCTest / physical-device testing.
