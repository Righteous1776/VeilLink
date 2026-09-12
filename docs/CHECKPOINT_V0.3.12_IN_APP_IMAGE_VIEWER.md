# V0.3.12 In-App Full-Screen Image Viewer

- Tap any locally available chat image to open it inside VeilLink.
- Full-screen black viewer supports pinch zoom to 5×, double-tap 2.5×, pan while zoomed, and swipe-down dismissal at 1×.
- Viewer starts immediately from the already decoded bubble thumbnail, then asynchronously replaces it with a larger ImageIO downsample.
- Decode budgets: SE1 1536 px; iPhone 7/7 Plus 2048 px; SE2 2560 px; iPhone 13 Pro and iPad Air 4 3072 px.
- Owner Mode high-definition preview override lifts the viewer decode ceiling to 4096 px.
- Large viewer image exists in memory only while presented; encrypted attachment storage and transport bytes are unchanged.
- No network access, Protocol 4 change, Schema migration, or attachment re-encoding is introduced.
