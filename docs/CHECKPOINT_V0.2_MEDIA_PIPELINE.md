# VeilLink V0.2 Media Pipeline Checkpoint

- Import from Photos or Files. The picker requests the current/original asset representation so RAW/DNG/ProRAW can reach the local preprocessing pipeline when iOS exposes it.
- Large source files are decoded from URL instead of loading the whole RAW into memory first.
- Long edge is capped at 4096 px. Quality is reduced gradually only after the size/dimension policy is applied.
- HEIC is preferred when the device can encode it; JPEG is the fallback. Small PNG graphics can stay lossless.
- Soft target: 1.8 MB. Hard Protocol 4 image limit: 3 MB.
- Transfer-safe MIME types: image/jpeg, image/heic, image/png. WebP/TIFF/BMP/RAW are import formats and are normalized before transport.
- Received images are saved with PhotoKit using the verified attachment bytes, not by re-rendering a UIImage.
- NSPhotoLibraryAddUsageDescription is already present; saving asks for add-only authorization on demand.
- Media capability expansion is Protocol 4. Schema V6 remains unchanged.
- Protocol 4 deliberately changes handshake/KDF/AAD domain labels so older JPEG-only v3 peers fail fast during handshake instead of failing mid-transfer.
