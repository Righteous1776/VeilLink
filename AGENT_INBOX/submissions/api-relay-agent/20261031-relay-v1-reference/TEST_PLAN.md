# TEST_PLAN — relay API and next iOS release gate
1. Run `cd FILES && python3 -m unittest -v test_relay_api.py` (observed PASS 10/10).
2. Compare fields exactly against product `VeilRelayPushRequest`, `VeilRelayRegisterRequest`, `VeilRelayAckRequest`, `VeilRelayPullResponse`, `VeilRelayStoredPacket`: timestamps are integer epoch milliseconds; encrypted Swift `Data` is JSON base64.
3. Add production tests for flooding, mailbox quotas, cross-process atomic operations, database loss recovery, random garbage, encrypted body limits, replay, token brute force, HTTPS reverse-proxy config, network timeouts and per-device performance.
4. Exercise both regional endpoints with separate storage and credentials. Prove full iPhone pair-recovery before claiming online service is live.
5. No production endpoint is supplied or configured in this submission. No version change, release tag or IPA allowed.
6. For release: check PR #121 latest head iOS CI build+XCTest+Release unsigned packaging. Failure in any test blocks merging #119/any version bump.
