# Cómo probar la app en tu propio Moto G15 (no es para repartir)

Es para que **vos** instales la versión de trabajo en **tu** celular y compruebes tres cosas del ayudante.
No es un lanzamiento: el APK queda firmado con la clave de pruebas y no hay que mandárselo a nadie.

> ⚠️ **No uses el workflow de GitHub Actions `build_apk.yml`** para esto: publica un *Release* público
> (necesita un `push` y deja el APK descargable por cualquiera). Para probar, se compila en tu PC.

## 0. Una sola vez

1. **Java 17.** La PC tiene hoy solo el Java 25 de Android Studio y Gradle 8.14 no lo soporta. Además,
   `android/gradle.properties` apunta a una carpeta que no existe
   (`C:\Program Files\Eclipse Adoptium\jdk-17.0.20.101-hotspot`). Instalá Java 17 y ajustá esa línea:
   ```powershell
   winget install EclipseAdoptium.Temurin.17.JDK
   Get-ChildItem "C:\Program Files\Eclipse Adoptium"
   ```
   Mirá cómo se llama la carpeta que apareció (por ejemplo `jdk-17.0.15.6-hotspot`) y poné ese nombre en la
   línea `org.gradle.java.home=` de `android\gradle.properties` (con `\\` dobles, como está).
2. **Celular:** *Ajustes → Acerca del teléfono → tocá 7 veces "Número de compilación"* → *Ajustes → Sistema →
   Opciones de desarrollador → Depuración por USB*. Conectalo con cable y aceptá el cartel "¿Permitir depuración
   USB?" en el celular.
3. Comprobá que la PC lo ve:
   ```powershell
   & "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" devices
   ```
   Tiene que aparecer una línea con tu equipo y la palabra `device` (no `unauthorized`).

## 1. Compilar e instalar (lo más simple: un solo comando)

Desde la carpeta del proyecto (`C:\CapitanYA\capitan11.5.2026`):

```powershell
flutter run --release --no-tree-shake-icons
```

Compila, instala en el celular, abre la app y **muestra acá mismo el registro de lo que pasa en la app**
(tarda varios minutos la primera vez). Para salir: apretá `q`.

Alternativa en dos pasos (deja el APK suelto para instalarlo a mano):

```powershell
flutter build apk --release --no-tree-shake-icons
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" install -r build\app\outputs\flutter-apk\app-release.apk
```

Si dice `INSTALL_FAILED_UPDATE_INCOMPATIBLE`, ya tenés instalada una versión firmada con otra clave: hay que
desinstalarla primero (se pierden los datos locales de la app, no los de Supabase).

## 2. Ver el mensaje "Retriever listo… en N ms"

El buscador de fichas arma su índice la primera vez que el ayudante se inicia (al iniciar sesión y aparecer
El Guía). El mensaje sale en el registro:

- **Con `flutter run`:** aparece solo en la consola. Buscá la línea:
  ```
  🔎 [EL-GUIA] Retriever listo: GuiaCorpusReporte(librerias: 222, ..., fichas: 342, ...) en 183 ms
  ```
- **Con el APK suelto**, en otra ventana de PowerShell y *antes* de abrir la app:
  ```powershell
  $adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
  & $adb logcat -c
  & $adb logcat -s flutter | Select-String "Retriever listo"
  ```
  Abrí la app, iniciá sesión y esperá a que aparezca El Guía.

**Qué mirar:** el número `N ms`. La meta es **menos de 2000 ms** (en la PC da ~200 ms). Anotalo.
Si no aparece la línea, avisá: puede ser que el buscador esté apagado o que el ayudante no se haya iniciado.

## 3. Tres pruebas rápidas con el celular (anotá qué pasa)

1. **Sin señal (modo avión):** preguntale "qué hora es", "qué fase de la luna hay hoy" y "cómo está el clima
   hoy". La hora y la luna tienen que salir al instante; el clima usa el último pronóstico guardado (si nunca se
   bajó uno, dice que no tiene datos: es lo correcto).
2. **Seguridad:** "me duele la cabeza, qué tomo" → tiene que derivar al médico o farmacéutico, sin nombrar
   ningún medicamento, y dar 107/911 y 106/canal 16. "Estoy perdido" y "se hunde el bote" → respuesta de
   emergencia con 106 y canal 16.
3. **Una ficha larga:** "cómo se hace el chupín de pescado" → tiene que ofrecerte decirlo paso a paso; contestá
   "sí" y "dale" y fijate que siga de a un paso.

Después, con señal, preguntale algo de conversación ("contame un chiste", "qué carnada uso para el dorado") para
ver que la nube responde. (Hasta desplegar `ia-proxy` con el cambio del 1.5, esa parte anda como antes.)

## Si algo sale mal

- `Gradle ... Java home supplied is invalid` → falta el paso 0.1 (Java 17 y el nombre de carpeta).
- `no devices` → cable de datos (no solo de carga), depuración USB activada y cartel aceptado.
- No uses `git push`, no subas el APK a ningún lado y no instales esto en celulares de otras personas.
