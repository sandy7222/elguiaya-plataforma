# Informe R.1 — Memoria de la app en el Moto G15 (2026-10-07)

> Paso R.1 de la Fase R (`docs/PLAN_AYUDANTE_IA.md`): **medir antes de tocar**. No se arregló nada. Este informe dice qué se midió,
> qué **se descartó con datos**, qué **no se pudo atribuir todavía** y cuál es el experimento que lo cierra.

**Equipo:** Moto G15, 3,78 GB de RAM, Android 15, GPU Mali-G52 (MediaTek MT6768), con el celular de uso diario del dueño
(WhatsApp Business, Facebook y otras apps abiertas). **App:** APK release de este repositorio. Herramientas:
`scripts/medir_memoria.mjs` (mide con `adb dumpsys meminfo`, solo lectura), `lib/services/diag_memoria.dart` (caché de imágenes de
Flutter, solo si se compila con `--dart-define=DIAG_MEM=true`) y `scripts/memoria_dart.dart` (heap de Dart, versión *profile*).

## 1. Resumen en seis líneas

1. **Android cierra la app estando en primer plano**, por falta de memoria del celular. Pasó en todas las corridas; el `lmkd` la
   mató con ~430 MB de RSS cuando al celular le quedaban ~78 MB libres. También mata el **servicio de voz de Google**
   (13:55:04: "crashed service … mem-pressure"), y por eso **la voz se corta a mitad de la explicación**.
2. La app llega a **700–1160 MB de PSS** (lo que Android le cobra) a los 30–60 segundos de abrirla, y **sigue subiendo ~5 MB/s**
   aunque no se toque nada.
3. **El ~65–70 % es memoria gráfica** ("Graphics": texturas y buffers de la GPU): 450 MB a los 8 s, 720 MB al minuto, 878 MB en
   la peor corrida. Todo lo demás (Java, nativo, código, pila) suma 200–300 MB.
4. **Se descartó**: el motor gráfico (Skia = Impeller), el heap de Dart (41 MB), el caché de imágenes de Flutter (73 MB, quieto),
   el avatar visible, y el arranque del Guía (522 ms con memoria libre).
5. **Sin atribuir todavía**: qué componente crea las texturas que crecen. Hay tres candidatos con evidencia (sección 5).
6. **Experimento que lo cierra**: tres versiones de diagnóstico, cada una cambia UNA cosa (sección 6).

## 2. Qué se midió (todas las corridas, Android `dumpsys meminfo`, en MB)

Arranque en frío, la app ya con sesión iniciada. *Libre* = memoria disponible en el celular.

| Corrida | Momento | PSS total | Graphics | Java | Native | Libre |
|---|---|---|---|---|---|---|
| Release, Impeller | +5 s | 483 | 293 | 13 | 47 | 1086 |
| | +15 s | 728 | 474 | 68 | 49 | 612 |
| | +30 s | 796 | 488 | 116 | 49 | 554 |
| | pantalla Mi identidad, +60 s | 793 | 486 | 125 | 47 | 580 |
| | **primera corrida: al volver al Panel** | **1164** | **878** | 34 | 27 | **297** (→ la mata el `lmkd`) |
| Release, **Skia** (sin Impeller) | +5 s | 415 | 164 | 9 | 47 | 1180 |
| | +15 s | 688 | 467 | 31 | 52 | 854 |
| | +30 s | 732 | 549 | 52 | 22 | 468 |
| | +60 s, **sin avatar a la vista** | **953** | **717** | 76 | 24 | 261 (→ muere sola) |
| Release + diagnóstico, Impeller | +8 s | 678 | 454 | 23 | 48 | 771 |
| | +20 s | 598 | 422 | 32 | 47 | 626 |
| | +40 s | 829 | 603 | 89 | 20 | 310 |
| | +60 s | **1018** | **722** | 51 | 17 | **181** |
| Profile, Impeller | +20 s | 767 | 468 | 80 | 54 | 691 |

Qué muestra la tabla: **Graphics sube de ~290 a ~720 MB en un minuto y el resto casi no se mueve.** Ese crecimiento es
**continuo en reposo** (≈ 5–6 MB por segundo entre los 20 y los 60 s).

Dentro de "Graphics" (volcado completo de `meminfo`): **EGL mtrack ≈ 258 MB** + **GL mtrack ≈ 241 MB** = 500 MB. `dumpsys gpu`
informó 222 MB de memoria Vulkan para el proceso de la app.

## 3. Qué se descartó

| Hipótesis | Evidencia en contra |
|---|---|
| El motor gráfico (Impeller/Vulkan) | Con Skia el número es **igual o peor**: 549 MB a los 30 s y 717 MB al minuto. |
| Los objetos de Dart | Heap de Dart **41,5 MB** usado (versión profile, vía el servicio de VM). |
| Las imágenes del caché de Flutter | `ImageCache`: **7 imágenes, 73 MB** (tope 100 MB), 27 "vivas", ninguna cargando, **constantes** mientras Graphics sube de 422 a 722 MB. |
| El avatar a la vista | En la corrida Skia el panel se vio **sin avatar** y Graphics llegó igual a 717 MB. |
| El arranque del Guía | Con el celular recién reiniciado: "Retriever listo" en **522 ms**. Los 4,8 s de la primera corrida eran por la falta de memoria. |
| El código (Code) | 15–90 MB, memoria mapeada y compartida. |

## 4. Otros hallazgos de la misma prueba (no son de memoria, pero salieron de ahí)

1. **La voz se corta:** el servicio de voz de Google fue matado por falta de memoria (ver arriba). No es un problema del código del Guía.
2. **Voz de red:** el TTS eligió `es-us-x-sfb-network` (necesita internet) y el reconocimiento usó `es_ES`. Es el punto 5.V.0 del plan.
3. **El cartel de conexión se contradice:** la barra superior dice **"Offline"** (amarillo) con el wifi conectado y el chat dice
   "IA Cloud · Groq Cloud activo · ONLINE". Hay dos estados distintos y uno está desactualizado. A investigar.
4. **La nube inventa datos y cita una fuente que no existe.** Ante "cómo está la pesca el día de hoy" respondió "Según el parte
   oficial… el nivel del río está medio, con aguas algo turbias". Los números del clima venían del lector del paso 1.0b; el
   "parte oficial" y el nivel/turbidez del río **no existen en ningún dato** que la app le dé. Rompe la regla 2 de `AGENTS.md`
   ("nunca inventar datos"). Además, esa pregunta no la atendió el lector determinista (no la detecta).
5. Un micrófono abierto capta ruido ambiente y manda frases sueltas a la nube ("Hola chamigo, me gustaría saber cómo…").

## 5. Candidatos para la memoria gráfica (sin probar todavía) y por qué

Todos con evidencia **a favor**, ninguna **medición que los aísle**:

1. **Los 22 GIFs del avatar.** Pesan ~30 MB en disco, pero decodificados ocupan **entre 17 y 63 MB cada uno** (426×240×4 bytes por
   cuadro, 44–162 cuadros): **~1,1 GB si se decodificaran todos**. El motor de Flutter decodifica los cuadros de un GIF en memoria nativa que
   el caché de imágenes de Dart **no cuenta**. Hay 33 flujos de imagen animada vivos y `capitan_asistente.dart` hace `precacheImage`
   de varios GIFs. Encaja con que la memoria **crezca con el tiempo** (se van decodificando los cuadros) y con que el caché de Flutter se vea chico.
2. **Las cuatro pestañas construidas a la vez.** `portal_pescador_screen.dart` usa un `IndexedStack` con Panel, Mapa, Tienda y Chat:
   **las cuatro se construyen y viven desde el arranque**, aunque se vea una. En toda la app hay **112 usos de `Image.network` /
   `NetworkImage` y solo 2 con `cacheWidth`**: las fotos de la tienda se decodifican a su tamaño real.
3. **Efectos de desenfoque (`BackdropFilter`)**: 32 archivos, hasta 12 por pantalla (`capitan_panel_screen`, `categories_grid_screen`). Cada
   uno pide una textura del tamaño de la pantalla (~10 MB). La pantalla Mi identidad, que no tiene ninguno, igual tiene 486 MB, así que
   no explica el piso, pero sí puede explicar el salto del Panel.

## 6. Experimento que cierra la atribución (próximo paso, R.3)

Tres compilaciones de diagnóstico, cada una cambia **una sola cosa** y se mide Graphics a los 20, 40 y 60 s con
`scripts/medir_memoria.mjs --serie`:

| Versión | Qué cambia | Si Graphics se achata → la causa es |
|---|---|---|
| V1 | los GIFs del avatar se reemplazan por una imagen fija | los GIFs (candidato 1) |
| V2 | el `IndexedStack` construye solo la pestaña activa | las pestañas ocultas y sus imágenes (candidato 2) |
| V3 | sin `BackdropFilter` en el Panel | los desenfoques (candidato 3) |

Con eso se sabe cuánto aporta cada una **antes de tocar nada de verdad**. Después, R.3 corrige lo que corresponda y se mide el
recorrido completo (login → mapa → Guía → 5 preguntas) contra la meta: **< 400 MB y ningún cierre**.

## 7. Cómo repetir las mediciones

```powershell
node scripts/medir_memoria.mjs --snap "momento"                 # una medición
node scripts/medir_memoria.mjs --serie 60 --cada 3 "momento"   # una cada 3 s
node scripts/medir_memoria.mjs --informe                        # tabla
flutter build apk --release --no-tree-shake-icons --dart-define=DIAG_MEM=true   # con el caché de imágenes en el registro
adb logcat -d -s flutter | findstr DIAG_MEM
```

Los números salen de `adb shell dumpsys meminfo com.example.capitanya_master` (PSS en KB; "Graphics" = GL mtrack + EGL mtrack + otros).

## 8. Resultado del experimento (R.3, mismo día, mismo celular)

Se probó **de a una cosa por vez**, midiendo con `scripts/medir_memoria.mjs` y el log `DIAG_MEM`:

| Variante | Qué cambia | Panel (reposo) | Abrir Tienda | Abrir Mapa | Abrir El Guía | Veredicto |
|---|---|---|---|---|---|---|
| Original | — | 750–950 MB, sube ~5 MB/s | — | — | — | muerto por `lmkd` en 20–60 s |
| a) sin GIFs | avatar con imagen fija | 775 MB, Graphics 494 | — | — | — | **NO son la causa** |
| b) pestañas perezosas | Mapa/Tienda/Chat se construyen al abrirlas | **271 MB, plano 85 s** (Graphics 126) | 688 → 776 MB | 833 → 973 MB | 1108 MB (se cierra) | **Sí: era una causa principal** |
| b + tope de imagen | decodificación ≤ 800 px (`AppBinding`) | 261 MB | 514 → 541 MB (caché de imágenes 93 → **12 MB**) | 614 → 733 MB | 844 → 945 MB | mejora la Tienda ~170 MB; sigue creciendo |
| b + tope + **sin video** | los banners con video no reproducen | 257 MB | 478 → 503 MB | 510 → 529 MB | **550 MB, plano** | **Los videos de los banners son lo que crecía** |

**Conclusiones medidas:**
1. **Las pestañas construidas todas a la vez** eran la mayor parte: el Panel solo usa ~260 MB; las otras tres pestañas, ocultas, sumaban ~500 MB.
2. **Los banners con video** (`VideoLoopPlayer`, `wantKeepAlive = true`, autoplay en bucle) son lo que **crece sin parar**: con video apagado, la memoria gráfica queda plana en ~294 MB en las cuatro pestañas (con video subía a 662 y 792 MB). Siguen decodificando aunque la pestaña esté oculta.
3. **Las fotos sin límite** pesaban 93 MB en el caché de Flutter (8 imágenes de ≈11,6 MB); con el tope de 800 px: 12 MB.
4. Recorrido completo (Panel → Tienda → Mapa → Guía): **1164 → 551 MB** sin video. Todavía arriba de la meta (< 400 MB): quedan ~190 MB de gráficos al abrir la Tienda que no explican las imágenes.

**Hecho (commits de R.3):** pestañas perezosas permanentes; `AppBinding` (tope de 800 px a toda decodificación; los GIFs del avatar no se tocan);
interruptores de diagnóstico `DIAG_SIN_GIF` / `DIAG_SIN_VIDEO` (apagados por defecto).

**Falta (en este orden):** (1) arreglar el video de verdad, no apagarlo: reproducir **solo el banner visible**, pausar y liberar el
controlador al ocultarse la pestaña o irse la app a segundo plano, y revisar la resolución de los videos subidos; (2) entender los ~190 MB
de la Tienda que quedan (candidatos: desenfoques, sombras, listas); (3) las 110 `Image.network` sin `cacheWidth` ya quedan cubiertas por el
tope global, pero conviene ponerles el tamaño real; (4) medir de nuevo el recorrido completo y confirmar **< 400 MB sin cierres**.
