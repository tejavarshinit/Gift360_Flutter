# Flutter engine / embedding
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Attributes needed by reflection-based libraries (Gson, annotation processors, etc.)
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod
-keepattributes SourceFile,LineNumberTable

# Play services (used internally by geolocator/geocoding)
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Play Core "deferred components" (dynamic feature delivery) — referenced
# conditionally by io.flutter.embedding.engine.deferredcomponents.* but this
# app doesn't use Play Feature Delivery, so these classes are absent on the
# classpath. Documented Flutter+R8 fix: suppress, don't keep.
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# WebView plugin (payment gateway flow)
-keep class io.flutter.plugins.webviewflutter.** { *; }

# Geolocator / geocoding
-keep class com.baseflow.geolocator.** { *; }
-keep class com.baseflow.geocoding.** { *; }

# Image picker
-keep class io.flutter.plugins.imagepicker.** { *; }

# JNI-called native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Parcelable CREATOR fields (platform channel argument marshalling)
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}

# Serializable implementations
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Enums (some libraries reflect on valueOf/values)
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}
