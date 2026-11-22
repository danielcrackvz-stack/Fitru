# Reglas para que R8 no rompa el motor de Flutter ni los canales de los plugins.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class dev.kufi.kufi.KufiHostApduService { *; }
-dontwarn io.flutter.embedding.**
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod
