# Verification

On the recorded main revision the patch applied to an isolated copy with whitespace checks enabled. Swift 6.0.3 frontend syntax parsing succeeded. A source assertion checked that the only added string interpolation is pin.count. Reversing the patch restored the original bytes.

For integration, build on Xcode and check the accessibility tree on a locked device in portrait and landscape. With VoiceOver, navigate to the indicator before entry, after entering two digits, after deleting one, and after an incorrect PIN resets. Expect one progress element reflecting 0, 2, 1 and 0 respectively. Check that the value contains only the count. Check the delete action is disabled when empty. Activate the Chinese-labeled biometric button on a configured device and verify the system authentication sheet. Apple SDK type checking, spoken output and physical authentication remain pending.
