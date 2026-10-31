# Manifest — board side selection R1

- Status: `VALIDATED_LOCAL_STATIC`; Apple SDK/XCTest/device gates pending.
- Lane: `INBOX_ONLY`
- base_main_sha: `e093e7fb7ab0eb9821a014b753ab2bdc27613ec8`
- Target dependency: Draft PR #114 head `14f2740620c0a73874df1588f146ad0f9a67589c`
- Candidate payload: `PATCH.diff`
- Product mutation in this branch: **none**

## Proposed scope

1. Let Gomoku players select black/first or white/second; let Xiangqi players select red/first or black/second.
2. Start the computer automatically when the player elects the second colour.
3. Preserve the existing role-based training-store contract when physical colours swap.
4. Add a second-colour AI-start regression test.
