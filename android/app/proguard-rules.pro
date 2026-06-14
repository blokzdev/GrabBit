# R8 keep rules for the release build.
#
# Flutter enables R8 (code shrinking) for `--release` builds. Several on-device
# AI libraries statically reference optional classes that are NOT on our
# classpath; in R8 full mode that fails the build with "Missing classes
# detected". We never construct the absent classes, so it is safe to silence the
# warnings — R8 drops the dead references. (Debug builds skip R8, which is why
# this only surfaced once the APK workflow defaulted to release.)

# --- ML Kit text recognition (google_mlkit_text_recognition, P13b-1) ---
# We ship only the bundled Latin recognizer; the plugin statically references the
# optional Chinese / Devanagari / Japanese / Korean recognizers, which we do not
# depend on and never instantiate.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# --- MediaPipe / LiteRT-LM (flutter_gemma) + AutoValue ---
# flutter_gemma's MediaPipe runtime references optional protobuf and AutoValue
# (@Memoized) classes reflectively; they are absent at compile time on our build.
-dontwarn com.google.mediapipe.**
-dontwarn com.google.auto.value.**
