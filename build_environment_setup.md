# Entorno de Compilación (Build Environment) - CapitanYA

## Requisitos Previos

### 1. Flutter SDK
- **Versión mínima**: Flutter 3.16.0 o superior
- **Instalación**: [Flutter Official Documentation](https://flutter.dev/docs/get-started/install)

### 2. Android SDK
- **Android Studio**: Latest Stable Version
- **Android SDK**: API Level 34 (Android 14)
- **Build Tools**: 34.0.0+
- **Platform Tools**: Latest Version

### 3. Java Development Kit
- **JDK**: Version 17 (LTS) o superior
- **JAVA_HOME**: Configurado correctamente

## Configuración del Proyecto

### 1. Estructura del Proyecto
```
capitanya/
├── lib/
│   ├── main.dart
│   ├── screens/
│   ├── services/
│   ├── widgets/
│   └── models/
├── android/
├── ios/
├── pubspec.yaml
└── build_environment_setup.md
```

### 2. Dependencias Clave (pubspec.yaml)
```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # Supabase
  supabase_flutter: ^2.0.0
  
  # UI
  cupertino_icons: ^1.0.6
  
  # State Management
  provider: ^6.1.2
  
  # Image Picker
  image_picker: ^1.0.7
  
  # Internationalization
  intl: ^0.18.1
  
  # HTTP
  http: ^1.1.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
```

## Configuración de Android

### 1. android/app/build.gradle
```gradle
android {
    namespace: 'com.capitanya.app'
    compileSdkVersion 34
    
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }
    
    kotlinOptions {
        jvmTarget = '17'
    }
    
    defaultConfig {
        applicationId: "com.capitanya.app"
        minSdkVersion 21
        targetSdkVersion 34
        versionCode 1
        versionName "1.0.0"
        
        multiDexEnabled true
    }
    
    buildTypes {
        release {
            minifyEnabled true
            shrinkResources true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
            
            // Firma del APK (reemplazar con tus keystore)
            signingConfig signingConfigs.release
        }
        
        debug {
            minifyEnabled false
            debuggable true
        }
    }
    
    signingConfigs {
        release {
            // Configurar keystore para firma
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
}

dependencies {
    implementation 'androidx.multidex:multidex:2.0.1'
}
```

### 2. android/gradle.properties
```properties
org.gradle.jvmargs=-Xmx4G -XX:MaxMetaspaceSize=2G -XX:+HeapDumpOnOutOfMemoryError
android.useAndroidX=true
android.enableJetifier=true

# Configuración de firma
keystore.path=../keystore.jks
keystore.password=tu_keystore_password
key.alias=tu_key_alias
key.password=tu_key_password
```

### 3. android/app/src/main/AndroidManifest.xml
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    
    <application
        android:label="Capitán YA"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher"
        android:usesCleartextTraffic="true">
        
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            
            <meta-data
              android:name="io.flutter.embedding.android.NormalTheme"
              android:resource="@style/NormalTheme"
              />
              
            <intent-filter android:autoVerify="true">
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
        
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>
</manifest>
```

## Comandos de Compilación

### 1. Limpieza y Dependencias
```bash
# Limpiar cache
flutter clean

# Obtener dependencias
flutter pub get

# Verificar dependencias
flutter pub deps
```

### 2. Verificación de Configuración
```bash
# Verificar configuración de Flutter
flutter doctor -v

# Verificar dispositivos conectados
flutter devices

# Verificar configuración de Android
flutter config --enable-web
```

### 3. Compilación APK

#### APK Debug (Para pruebas)
```bash
# Compilar APK Debug
flutter build apk --debug

# Compilar APK Debug con firma
flutter build apk --debug --split-per-abi
```

#### APK Release (Para producción)
```bash
# Compilar APK Release
flutter build apk --release

# Compilar APK Release optimizado
flutter build apk --release --split-per-abi --shrink

# Compilar APK Release con firma específica
flutter build apk --release --split-per-abi --keystore keystore.jks --store-password password --key-password password --key-alias alias
```

#### App Bundle (Recomendado para Google Play)
```bash
# Compilar App Bundle Release
flutter build appbundle --release

# Compilar App Bundle optimizado
flutter build appbundle --release --shrink
```

## Optimización de Build

### 1. ProGuard Configuration
**android/app/proguard-rules.pro**
```proguard
# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }

# Supabase
-keep class io.supabase.** { *; }

# Gson
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# OkHttp
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
```

### 2. Build Performance
```bash
# Habilitar compilación paralela
export GRADLE_OPTS="-Dorg.gradle.parallel=true"

# Configurar memoria de Gradle
export GRADLE_OPTS="$GRADLE_OPTS -Xmx4g -XX:MaxMetaspaceSize=512m"

# Compilación con cache
flutter build apk --release --split-per-abi --build-cache
```

## Verificación Post-Compilación

### 1. Validación del APK
```bash
# Verificar firma del APK
keytool -printcert -jarfile build/app/outputs/flutter-apk/app-release.apk

# Analizar tamaño del APK
ls -la build/app/outputs/flutter-apk/

# Verificar permisos del APK
aapt dump permissions build/app/outputs/flutter-apk/app-release.apk
```

### 2. Testing del APK
```bash
# Instalar APK en dispositivo conectado
adb install build/app/outputs/flutter-apk/app-release.apk

# Verificar instalación
adb shell pm list packages | grep capitanya

# Iniciar aplicación
adb shell am start -n com.capitanya.app/.MainActivity
```

## Troubleshooting Común

### 1. Errores de Compilación
```bash
# Si hay errores de dependencias
flutter pub cache repair
flutter pub get

# Si hay errores de Gradle
cd android
./gradlew clean
./gradlew build

# Si hay errores de firma
keytool -genkey -v -keystore keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias key
```

### 2. Problemas de Rendimiento
```bash
# Analizar APK
flutter build apk --analyze-size

# Reducir tamaño de APK
flutter build apk --release --split-per-abi --tree-shake-icons
```

### 3. Configuración de Firma
```bash
# Generar keystore para desarrollo
keytool -genkey -v -keystore debug.keystore -keyalg RSA -keysize 2048 -validity 10000 -alias debug

# Configurar firma en local.properties
echo "storeFile=../debug.keystore" > android/local.properties
echo "storePassword=android" >> android/local.properties
echo "keyPassword=android" >> android/local.properties
echo "keyAlias=debug" >> android/local.properties
```

## Checklist Pre-Release

- [ ] Flutter doctor sin errores
- [ ] Dependencias actualizadas (`flutter pub get`)
- [ ] Configuración de firma correcta
- [ ] ProGuard configurado
- [ ] APK de prueba funcional
- [ ] Tests unitarios pasando
- [ ] Iconos ysplash screen configurados
- [ ] Permisos mínimos configurados
- [ ] Versión y build number actualizados

## Comandos Finales

### Compilación para Producción
```bash
# Paso 1: Limpieza completa
flutter clean
cd android && ./gradlew clean && cd ..

# Paso 2: Dependencias
flutter pub get

# Paso 3: Compilación APK Release
flutter build apk --release --split-per-abi --shrink

# Paso 4: Verificación
ls -la build/app/outputs/flutter-apk/
```

### Compilación para Google Play
```bash
# Compilar App Bundle
flutter build appbundle --release --shrink

# Verificar bundle
ls -la build/app/outputs/bundle/release/
```

---

**Nota**: Reemplazar los valores de keystore con los tuyos propios antes de la compilación final.
