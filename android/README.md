# VeilLink Android

Native Android platform tree introduced by `ANDROID_DUAL_PLATFORM_V1`.

## Toolchain contract
- Android Gradle Plugin: 9.4.0
- Gradle: 9.6.0 (provisioned by CI)
- JDK: 17
- compileSdk / targetSdk: 36
- minSdk: 26
- Bouncy Castle: 1.86
- ZXing Core: 3.5.4

This repository intentionally does not vendor a Gradle wrapper JAR in the cumulative package. The canonical GitHub workflow provisions Gradle 9.6.0 with `gradle/actions/setup-gradle`. A wrapper can be generated only after the first successful Android CI build and then committed as a later maintenance unit.

## CI build
`gradle -p android :protocol-core:testDebugUnitTest :app:testDebugUnitTest :app:assembleDebug :app:assembleRelease`

The debug APK is installable with the Gradle-generated debug signature. The release APK is intentionally unsigned until a project-controlled Android release keystore policy is added.
