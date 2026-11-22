# Make the lock keypad readable with VoiceOver

The six PIN circles encode progress using fill and stroke. A VoiceOver user navigating back to them lacks an accessible count. The biometric and delete buttons use symbols with no app-defined action labels.

Expose the circles as one element labeled 密码输入进度, with an accessibility value derived solely from the number of digits entered. Label the two buttons 使用生物识别解锁 and 删除上一位数字. Disable delete while the input is empty. Both layout orientations use these same views.
