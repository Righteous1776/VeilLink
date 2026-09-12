# VeilLink Current Checkpoint

V0.3.7 iPhone 7 Render Compatibility, based on GitHub main 7397c537 after the V0.3.6 runtime optimization sync and subsequent iOS 15 fixes. Protocol 4 and SQLite Schema V8 remain unchanged. This checkpoint adds an automatic lightweight SwiftUI compositor path for iPhone 7 / 7 Plus on iOS 15, eliminates persistent decorative transit animation from static identity states, and reduces clip/shadow/background off-screen composition on the affected hardware while preserving the Veil visual identity.
