plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "dev.blokz.grabbit"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Required by flutter_local_notifications (uses java.time on older APIs).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "dev.blokz.grabbit"
        // ffmpeg_kit_flutter_new requires API 24+; take the higher of it and
        // Flutter's default.
        minSdk = maxOf(24, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // youtubedl-android extracts a bundled Python at runtime, so its .so files
    // must be page-aligned and uncompressed on disk (paired with
    // extractNativeLibs="true" in the manifest).
    packaging {
        jniLibs {
            useLegacyPackaging = true
            // youtubedl-android ships its Python/ffmpeg payloads as *.zip.so
            // archives (not real ELF). Exclude them from NDK stripping, which
            // otherwise logs "not a valid object file" errors.
            keepDebugSymbols += listOf("**/libpython.zip.so", "**/libffmpeg.zip.so")
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")

            // Flutter shrinks release builds with R8. The on-device AI libraries
            // (ML Kit text recognition, flutter_gemma/MediaPipe) reference
            // optional classes that aren't on our classpath, so R8 full mode
            // needs explicit keep rules or it fails with "Missing classes
            // detected". Resource shrinking stays off (the failure is code-only).
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // On-device download engine: yt-dlp + Python + ffmpeg, bundled as native libs.
    implementation("io.github.junkfood02.youtubedl-android:library:0.17.3")
    implementation("io.github.junkfood02.youtubedl-android:ffmpeg:0.17.3")

    // On-device graph + vector DB (P10): CozoDB relational-graph-vector engine,
    // MPL-2.0. Bundles native .so for arm64-v8a + x86 only; on other ABIs the
    // graph store degrades gracefully (see lib/core/graph/ + docs/GRAPH-SPEC.md).
    implementation("io.github.cozodb:cozo_android:0.7.2")

    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2")

    // NotificationCompat / ContextCompat for the download foreground service.
    implementation("androidx.core:core-ktx:1.13.1")
    // DocumentFile for SAF folder export.
    implementation("androidx.documentfile:documentfile:1.0.1")
}
