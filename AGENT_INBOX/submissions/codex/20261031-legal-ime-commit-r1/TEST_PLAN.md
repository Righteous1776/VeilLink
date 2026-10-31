# Test plan

1. Fresh install on iPhone 7: switch between “权限授权说明” and “责任边界”; verify both remain hittable.
2. Toggle all three confirmations by tapping both checkbox glyph and multiline label regions.
3. With Simplified Chinese Pinyin, leave the final characters in marked composition, tap “签署并进入” once, and verify the committed exact phrase is accepted without a second tap.
4. Repeat with hardware keyboard, system English keyboard, paste, clear button and VoiceOver.
5. Enter a wrong phrase and verify one validation error appears and the button becomes usable again.
6. Rapidly double tap with a valid phrase and verify exactly one acceptance record/ID is stored.
7. Inject keychain write failure and verify the error is shown, signing unlocks, and no partially valid record is accepted.
8. Run `LegalConsentTests`, `PreConsentBlackBoxTests`, pre-consent UI smoke, full XCTest and physical-device touch/IME regression.
