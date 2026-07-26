# AGENTS.md

## Cursor Cloud specific instructions

### Proyecto
App **Flutter** "Capitán YA / El Guía YA" (paquete `capitanya_master`): asistente de pesca deportiva del Río Paraná. Multiplataforma (web, Android, iOS, desktop); el target principal para desarrollo/pruebas rápidas es **web** (se despliega en Vercel sirviendo `public/`). Backend: **Supabase remoto** con URL y `anon key` embebidas en `lib/services/supabase_service.dart` (con override opcional vía `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`). No hace falta ningún secreto para arrancar en modo dev.

### Toolchain
- Flutter **3.41.9** / Dart **3.11.5** (coincide con `.metadata`; el pubspec exige Dart `>=3.11.5`). Instalado en `/home/ubuntu/flutter` y agregado al `PATH` vía `~/.bashrc`. Si `flutter` no está en el `PATH`, usar `/home/ubuntu/flutter/bin/flutter`.
- El update script ya corre `flutter pub get`. Web ya está habilitado (`flutter config --enable-web`).

### Comandos (ver también `build_environment_setup.md`)
- Lint/análisis: `flutter analyze`
- Tests: `flutter test` (14 tests del motor offline `ElGuiaEngine`; pasan. Nota: emiten warnings benignos `MissingPluginException` de `path_provider` porque no hay plugins nativos en el test host — el motor cae a assets y funciona).
- Correr web (dev): `flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080 -t <entrypoint>` y abrir `http://localhost:8080` en Chrome (`google-chrome` está instalado). El device `web-server` no necesita display.
- Build APK release (CI): `flutter build apk --release --no-tree-shake-icons`.

### GOTCHA CRÍTICO — el entrypoint principal NO compila en `main`
`lib/main.dart` (y la mayoría de la app, porque casi todo enruta a `lib/services/supabase_service.dart`) **no compila** en el estado actual del repo por código faltante pre-existente, NO por el entorno:
- Archivos referenciados que no existen: `lib/screens/admin_reclamos_tienda_screen.dart`, `lib/screens/admin_importacion_screen.dart`, `lib/services/subasta_lifecycle_policy.dart` (importado por `supabase_service.dart`), `lib/models/tipo_checkout.dart`, `lib/utils/text_input_formatters.dart`.
- Paquetes usados pero no declarados en `pubspec.yaml`: `lottie`, `video_player`.
- Métodos/identificadores indefinidos en `supabase_service.dart`: `NotificacionHelper.pedidoDespachado/pedidoEntregado`, `AfipService.generarFacturaSiCorresponde`, `SubastaLifecyclePolicy`.

`flutter analyze` lista estos como errores (también quedaron registrados en los `errors*.txt` / `analyze_output.txt` versionados). Hasta que se agreguen esos archivos/deps, `flutter run`/`flutter build` con `lib/main.dart` fallan en compilación. `flutter analyze` y `flutter test` sí funcionan porque los tests solo importan `lib/services/el_guia_engine.dart`, que compila limpio de forma aislada. La mayoría de los `lib/main_*.dart` alternativos están vacíos o dependen también de `supabase_service.dart`.
