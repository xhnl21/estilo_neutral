# Reglas de R8/ProGuard para el build de release.
# Sin esto, isMinifyEnabled/isShrinkResources pueden romper en runtime el
# código que las librerías nativas de estos plugins resuelven por reflection
# (Google Sign-In vía Play Services, biometría, ExoPlayer/Media3).

# Flutter embedding — el propio motor ya viene con sus reglas, pero se
# refuerza para no perder nada si cambia la versión del engine.
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# Google Play Services / Google Sign-In (google_sign_in_android)
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# flutter_secure_storage (Android Keystore / EncryptedSharedPreferences)
-keep class androidx.security.crypto.** { *; }
-dontwarn androidx.security.crypto.**

# local_auth (biometría / huella / rostro)
-keep class androidx.biometric.** { *; }
-dontwarn androidx.biometric.**

# video_player (Media3/ExoPlayer) — splash con video
-keep class androidx.media3.** { *; }
-dontwarn androidx.media3.**

# Atributos que varias de las libs de arriba necesitan preservar para
# resolver anotaciones/generics en tiempo de ejecución.
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod
