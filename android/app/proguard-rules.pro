# Flutter/Android proguard rules – keep Flutter embedding and plugins
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.app.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.util.** { *; }

# Keep generated registrant
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }

# Keep all model classes (JSON serialization)
-keep class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Keep Kotlin Metadata
-keep class kotlin.Metadata { *; }

# Keep plugins
-keep class com.** { *; }
-keep class xyz.** { *; }

# Keep Play Core library classes for deferred components (optional but prevents errors)
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# Avoid warnings for annotation processors and Kotlin metadata
-dontwarn org.jetbrains.annotations.**
-dontwarn kotlin.**

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Preserve annotated classes and members
-keepattributes *Annotation*,Signature,Exception,InnerClasses,EnclosingMethod

# Keep enum classes
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}
