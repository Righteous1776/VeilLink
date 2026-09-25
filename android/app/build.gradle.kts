plugins {
    id("com.android.application")
}

android {
    namespace = "studio.zeo.veillink.android"
    compileSdk = 36

    defaultConfig {
        applicationId = "studio.zeo.veillink.android"
        minSdk = 26
        targetSdk = 36
        versionCode = 52
        versionName = "0.10.10-android-v1"
        testInstrumentationRunner = "android.test.InstrumentationTestRunner"
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
        debug {
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

dependencies {
    implementation(project(":protocol-core"))
    implementation("org.bouncycastle:bcprov-jdk18on:1.86")
    implementation("com.google.zxing:core:3.5.4")
    testImplementation("junit:junit:4.13.2")
}
