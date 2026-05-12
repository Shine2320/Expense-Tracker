# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Google Play Core (Flutter references these but we don't use Play Feature Delivery)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# Hive
-keep class com.hivestreaming.** { *; }
-keep class org.xerial.snappy.** { *; }
-dontwarn org.xerial.snappy.**

# Keep model classes
-keep class * extends java.util.List { *; }
-keep class * extends java.util.Map { *; }

# Keep custom model constructors
-keep class ** {
    public <init>(...);
}

# Gson (if any)
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
