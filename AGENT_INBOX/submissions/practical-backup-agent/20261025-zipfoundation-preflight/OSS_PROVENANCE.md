# Third-party ZIPFoundation reuse

Existing VeilLink `project.yml` already declares `ZIPFoundation` from `0.9.19`. There is **no new third-party dependency** and no vendor source or dataset copied into this package.

Upstream: https://github.com/weichsel/ZIPFoundation
License: MIT (preserve attribution already appropriate to existing packaged dependency).
Tag consulted: https://github.com/weichsel/ZIPFoundation/tree/0.9.19

Public API confirmed against official tagged sources: `Archive(url:accessMode:.read)`, iterator yielding `Entry`, `Entry.path`, `.type`, `.compressedSize`, `.uncompressedSize`, `.checksum`, and `Archive.extract(_:bufferSize:skipCRC32:consumer:)` which streams data and returns CRC32. ZIP allows duplicate paths, so callers must explicitly check all entries instead of retrieving only `archive[path]` (which returns the first matching entry).

The app's existing `FileManager.unzipItem` and path checks are preserved; this proposal adds pre-restoration diagnostics and defense in depth. Full ZIPFoundation binary build on Apple toolchain is still mandatory.
