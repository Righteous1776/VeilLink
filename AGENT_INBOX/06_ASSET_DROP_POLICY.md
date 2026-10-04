# Asset Drop Policy

Agent Inbox V1 supports a limited binary-resource exception called **Asset Drop**.

Asset Drop does not grant product-tree write access. It only allows an explicitly authorized agent to place auditable art/model resources inside its own Inbox submission.

## Grant marker

A grant is identified by:

`[INTEGRATION-GOVERNOR][ASSET-DROP-GRANT]`

Machine-readable grants live in:

`AGENT_INBOX/ASSET_GRANTS.json`

Without an active grant for the agent, binary resources remain forbidden.

## Resource location

Granted resources must live only under:

`AGENT_INBOX/submissions/<agent-id>/<task-id>/ASSETS/`

If `ASSETS/` contains any file, the submission must also contain:

`ASSET_MANIFEST.json`

at the submission root.

## Allowed resource classes

The initial Game Agent grant allows:

- PNG: `.png`
- JPEG: `.jpg`, `.jpeg`
- WebP: `.webp`
- glTF: `.gltf`, `.glb`
- Wavefront: `.obj`, `.mtl`
- USDZ: `.usdz`

Text shaders/source such as Metal, Swift, JSON or shader snippets should stay in `PATCH.diff` or `FILES/`, not in `ASSETS/`.

## Quota

The active grant defines its own quota.

Initial Game Agent quota:

- maximum 16 asset files per submission;
- maximum 12 MiB per asset file;
- maximum 48 MiB total asset payload per submission.

The Governor may reduce, expand, revoke, or replace a grant.

## Licensing and provenance

Every asset must have an entry in `ASSET_MANIFEST.json` containing:

- repository-relative asset path;
- stable resource alias;
- original source URL;
- license identifier;
- SHA-256;
- exact byte count;
- intended purpose;
- attribution text when required.

Initial accepted license identifiers:

- `CC0-1.0`
- `PUBLIC-DOMAIN`
- `CC-BY-4.0`
- `MIT`
- `Apache-2.0`
- `BSD-2-Clause`
- `BSD-3-Clause`

Do not submit an asset if its redistribution license is unclear.

## Still forbidden

Asset Drop does not allow:

- ZIP / 7z / RAR / tar archives;
- IPA, app bundles, frameworks, dylibs, executables or object code;
- model weights;
- provisioning/signing material;
- secret/private files;
- generated build products;
- opaque binary blobs with unapproved extensions;
- files outside the agent's own submission root.

## Integration

Staged assets remain proposals.

The Integration Governor may:

- import them unchanged;
- optimize/transcode them;
- rename aliases;
- reject individual assets;
- replace them with a better equivalent;
- defer them to a later integration batch.

An Asset Drop grant never authorizes direct addition to the VeilLink product/resource tree.
