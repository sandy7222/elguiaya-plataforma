# Estado del proyecto — bitácora

> **Lo actualiza la IA que trabaja, al terminar cada paso** (ver `AGENTS.md`). Escribir corto, con fecha y commit.
> Lo más reciente va arriba en cada sección. Nada de secretos acá.

**Última actualización:** 2026-10-06 · Sonnet (Fase 2: evaluación, registro anónimo, exportar CSV) · rama `fase-0-contencion` · subida a GitHub (push del 2026-10-06, hasta `552d7d6`; el dueño dio el OK).

## Dónde quedamos

### Ayudante "El Guía" (`docs/PLAN_AYUDANTE_IA.md`)
- **Fase 0 (seguridad): CERRADA.** Pasos 0.1 a 0.6 + 0.3b/c/d y 0.4b. Último commit de la fase: `07c0c38`.
- **Fase 1, hechos:** 1.1 BM25 prendido (`47195d1`) · 1.2 presentador de fichas (`4a9c7dc`) ·
  1.0 navegación solo con pedido explícito (`36f3e0e`) · 1.0b hora/luna/clima determinista (`713c0cd`) ·
  1.3 "no tengo ese dato" honesto (`dfd658b`) · 1.4 sin retraso artificial (`86661a6`) ·
  1.5 Groq más rápido + arreglo de la codificación UTF-8 del proxy (`82d7a7f`) ·
  1.6 circuit breaker y timeout de 6 s (`72b9063`) · 1.2b texto para voz (`1df2654`) ·
  instrucciones comunes para IAs (`5cf8de2`) · salud sin emergencia: deriva, nunca receta (`7418675`) ·
  1.3b dos arreglos baratos contra respuestas sin relación (`76807c5`) ·
  1.2c parte 1: tildes en las respuestas, script `scripts/revisar_tildes.mjs` (`e988000`) ·
  1.2c parte 2: léxico de pronunciación `assets/elguia/voz/pronunciacion.json` (`7554597`).
- **Fase 2, hecha en parte:** 2.3/2.4 conjunto de evaluación y runner (`b289e47`, `test/eval/`, `test/eval_guia_test.dart`) ·
  2.1 registro anónimo (`497214d`) · 2.2 alternativa sin tocar la base: exportar CSV desde Admin → Sistema → "Registro de
  preguntas" (`721d702`) · 2.2 migración de la tabla **escrita y SIN APLICAR** (`d41ef65`).
- **Primera medición (offline), real vs generada** — `flutter test test/eval_guia_test.dart` → `build/eval_guia/informe.md`:
  seguridad 100 % (real 13/13, generada 153/153); pesca top-1 88,7 % y directas equivocadas 0 % (**solo de plantilla**: no
  hay preguntas de pesca reales con etiqueta todavía); fuera de dominio: falso positivo del buscador 4 % pero 22 % inventado de
  punta a punta (generada). Preguntas reales de pesca: "carpa" ✘ (lista peces), "comer" contesta con una ficha de carnadas.
- **Flags nuevos** (todos en `SharedPreferences`, todos prendidos salvo el retraso): `guia_nav_estricta`,
  `guia_condiciones`, `guia_no_se_honesto`, `guia_retraso_artificial` (apagado), `guia_groq_rapido`,
  `guia_breaker`, `guia_voz_limpia`, `guia_presentador`, `guia_bm25` (ver 1.1), `guia_aclarar_estricto`,
  `guia_ayuda_app_estricta`.
- **Tests:** 1558 pasan, 1 salteado (`flutter test`, ~20 s). Proxy: `node --test supabase/functions/ia-proxy/groq_params.test.ts`.

## Qué sigue (en este orden)

00. **Orden fijado por Opus (2026-10-07):** (1) **R.3** diagnóstico de memoria de a una variante, midiendo la curva de memoria
    gráfica en el Moto G15: a) sin GIFs → si se aplana, corregir directo (una sola animación viva, no precargar todas, pausar
    pestañas ocultas con `TickerMode`, GIFs más chicos); b) pestañas que se construyen al abrirlas; c) sin desenfoque en el Panel.
    Aparte, aunque no sea la causa: las 110 `Image.network` sin `cacheWidth`/`cacheHeight`. (2) **1.8 hecho** (`9093f97`): la nube
    no inventa datos (prompt + verificador + ruteo de "cómo está la pesca hoy" al lector). (3) **Después**, en este orden:
    - el cartel **"Offline"** (barra superior) con wifi mientras el chat dice "ONLINE": deben leer la misma fuente de verdad, el
      estado del breaker del 1.6;
    - el **micrófono** que manda ruido a la nube: mitigación rápida = ignorar resultados del reconocedor de baja confianza o de
      menos de 2 palabras (el resto queda en la Fase 4.M);
    - el bloque de aprendizaje `|||APRENDO|||` de la nube no pasa por el verificador (puede guardar datos inventados).
    **R.3 medido (detalle en `docs/INFORME_MEMORIA_R1.md`, sección 8):** a) los GIFs NO son la causa; b) **las pestañas construidas
    todas a la vez sí** (Panel solo: 271 MB plano; antes 750–950); y **los banners con video** son lo que crece sin parar (sin video:
    plano en ~294 MB de gráficos). Hecho: pestañas perezosas permanentes + tope de 800 px a toda decodificación de imágenes
    (`AppBinding`; caché de imágenes 93 → 12 MB). Recorrido completo: 1164 → **551 MB** (sin video). **Falta** (meta < 400 MB):
    arreglar el video de verdad (solo el banner visible, pausar/liberar al ocultarse), entender los ~190 MB de la Tienda que quedan,
    y volver a medir.
    **R.3b hecho en código (falta medir en el Moto G15: el celular quedó "unauthorized" en adb, hay que aceptar el aviso de depuración USB):**
    regla del dueño: los videos se reproducen solo con la Tienda abierta y a la vista; al salir de la Tienda o pasar la app a segundo
    plano el reproductor se **libera** (dispose), no se pausa; fuera de la Tienda hay **0** reproductores y dentro **uno solo** (el del
    banner visible, tope `BannerVideoCache.maxReproductores = 1`). Equipos de 4 GB o menos (RAM por canal nativo `capitanya/dispositivo`):
    imagen fija en vez de video (ahora es un fondo con ícono de play: los banners no tienen imagen de portada aparte). Se sacó el
    "calentado" del caché (`preloadAll` ya no hace nada). Tests: `banner_video_politica_test.dart`, `banner_video_tienda_test.dart`
    (Tienda cerrada / app en segundo plano / cierre → 0 reproductores). Como el Moto G15 es de 4 GB, **ahí no va a haber video**: la
    medición esperada es la del caso "sin video" (~551 MB). **Después:** los ~190 MB gráficos de la Tienda (desenfoques, sombras,
    listas), de a una variante por vez; luego **R.5** (sacar el admin del APK, agregado por el dueño) y R.4 (tamaño del APK).
    **R.3b MEDIDO en el Moto G15 (2026-10-07, APK de perfil `e7286cd`):** Panel 265 MB → Tienda 316 → Mapa 297 → El Guía 297 → vuelta a
    la Tienda 297 MB, **plano, sin crecer** (gráficos 102 MB; antes 294). Recorrido completo: 1164 → 945 → 551 → **~300 MB**: meta
    (< 400 MB) cumplida en el recorrido sin preguntas al Guía. Los "~190 MB de la Tienda" desaparecieron con este cambio (eran el video
    de los banners), así que **ya no hace falta investigar desenfoques/sombras/listas**. **Falta:** repetir con 5 preguntas al Guía con
    voz (TTS) para confirmar que no hay cierres, y un equipo de más de 4 GB para ver el video real.
    **Prueba con voz en el Moto G15 (2026-10-07, avatar activo, el dueño hablando, 4 min):** PSS 347–376 MB, sin cierre de la app
    (Android sí mató a otras apps). Micrófono: la app lo pide a los 0,25 s y Google lo abre a los 0,4 s; "Te escucho…" a ~1 s; la luz verde
    de Android a ~2,5 s (la dibuja el sistema). Hallazgos NUEVOS, a priorizar (todos de voz/IA, no de memoria):
    - **El Guía inventa en una pregunta de pesca ("pesca de mojarra"):** el router la clasificó `saludo_pescador`, la mandó a la nube
      ("Charla detectada — skip contexto") y el verificador solo reemplazó 1 afirmación; el resto es texto libre del modelo. Falta que las
      preguntas de técnica/carnada/especie pasen por las fichas (retrieval) y, sin ficha, digan "no tengo ese dato".
    - **El aprendizaje automático guarda esas respuestas inventadas:** `gemini_learner.dart` las escribe como conocimiento "pendiente", las
      consolida a la 3.ª vez y las sube a Supabase (el registro mostró "Conocimiento auto-guardado en Supabase … como_pescar_mojarra").
      Después el motor offline las sirve como verdad. Propuesta: apagarlo por flag hasta que haya verificación (decide el dueño).
      **HECHO (paso 2):** flag `guia_aprendizaje_auto`, por defecto apagado (`GeminiLearner.aprendizajeAutomatico`; corta en `procesar` y
      `evaluarYGuardar`, o sea también el bloque `|||APRENDO|||` de la nube). Test `test/gemini_learner_apagado_test.dart`; los tests de
      seguridad del aprendizaje (`learner_seguridad_test.dart`) siguen igual de estrictos, solo encienden el flag en su `setUp`.
      **Pendiente con OK del dueño:** lo ya guardado sigue ahí: en el celular de prueba (`guia_aprendido_pendiente/como_pescar_mojarra.json`)
      y en la tabla `guia_conocimiento_distribuido` de Supabase (la intención `como_pescar_mojarra`, id `609ad12b-…`). Revisar y borrar
      lo inventado (borrar datos = necesita OK explícito). El prompt de la nube todavía le pide escribir `|||APRENDO|||` (gasta palabras
      sin servir): se saca cuando se reescriba el prompt (paso 3).
    - **Micrófono en bucle:** cada ~6 s se abre y falla con `error_language_not_supported` (idioma `es-ES` sin paquete sin conexión, STT por
      red); gasta batería y es la fuente del "ruido ambiente". Hay que cortarlo tras el error y no reabrir solo.
      **Causa hallada:** es el *wake word* (`voice_service.dart` `_runWakeWordBurst`, llamado desde `guia_overlay.dart:644` cuando el Guía
      duerme): abre el micrófono cada 6 s con `onDevice: true` y `es_AR`, y el celular no tiene ese paquete → falla al instante. Es la luz
      verde y el "ruido" que ve el dueño. No sirve de nada hoy (nunca reconoce) y hay que apagarlo hasta tener el paquete sin conexión.
      **HECHO (paso "wake word apagado"):** flag `guia_wake_word`, por defecto apagado (`lib/services/guia_wake_word.dart`; lo respetan el overlay
      y `VoiceService`). Test `test/guia_wake_word_test.dart`. Para encenderlo de nuevo: `SharedPreferences` `guia_wake_word` = true. **Falta
      verificarlo en el celular** (instalar APK nuevo: la luz verde no debería aparecer con el Guía acostado).
    - **Respuestas largas que venden y dan contacto:** el prompt de la nube (`capacitacion_service.dart` ~líneas 100–115) le ordena ser
      "ASESOR DE VENTAS… impulsar la venta", "usá tienda/catálogo sin dudar ni avisar que no podés", "NUNCA digas que no tenés el URL" y
      "respondé siempre con estos datos" de contacto (email/teléfono). Por eso, tras decir que no tiene el dato, sigue con un recorrido de la
      tienda y la dirección/correo. Además lleva conocimiento de pesca por zona escrito en el prompt (fuente de invención). Sin tope de
      palabras para la voz: el TTS lee todo, minutos. Propuesta: prompt corto, sin rol de ventas, respuesta de voz ≤ 3 oraciones, y que
      ante "no tengo ese dato" corte ahí.
    - **Hay que apretar el botón cada vez que se quiere hablar** (no hay modo conversación); mejora de la Fase de voz.
    - **HECHO (paso 3):** prompt de la nube nuevo (`lib/services/guia_prompt_nube.dart`, ~1200 caracteres): 3 oraciones para voz, sin rol de
      ventas, sin conocimiento de pesca escrito a mano, sin contacto salvo que lo pidan, sin `|||APRENDO|||` (solo con el flag de
      aprendizaje encendido). Más `GuiaVerificadorDatos.cortarTrasSinDato`: si la 1.ª oración de la nube es un "no tengo ese dato", se
      descarta lo que sigue. Tests `guia_prompt_nube_test.dart` y `guia_sin_dato_test.dart`. **Efecto esperado:** la nube ya no contesta
      pesca "de memoria"; el conocimiento tiene que venir de las fichas (paso 4). El chat ya no promete que un reclamo "queda guardado"
      (no lo guardaba). Falta probarlo en el celular con un APK nuevo.
    - **HECHO (paso 4):** el conocimiento de pesca (técnica, carnada, especie, equipo) lo contesta el motor local con fichas, con o sin señal
      (`lib/services/guia_ruta_conocimiento.dart`, flag `guia_pesca_local`, encendido; el router lo consulta antes de la nube). Compara
      palabras enteras. Probado contra el motor real: surubí, dorado, pejerrey y nudo palomar salen de fichas; "pesca de mojarra" →
      "Eso no lo tengo, chamigo…" (no hay ficha de mojarra: **falta cargarla**, con revisión de una persona idónea). La nube queda para la
      charla. Tests `guia_ruta_conocimiento_test.dart`. **Tests ajustados (no debilitados):** `ia_breaker_test.dart` (usaba frases de
      pesca como "pregunta que llega a la nube": ahora usa charla; lo que prueba, el breaker, no cambia), `router_seguridad_test.dart`
      (impaciencia: las frases de pesca ahora verifican "no recibe el chiste" y que no va a la nube; la de "el modo emergencia vence"
      usa una frase de charla). Los tests de seguridad propiamente dichos no se tocaron.
      **Pedido del dueño (2026-10-07):** el Guía no habla de la tienda salvo que el cliente pregunte o esté en la pantalla de la Tienda
      (commit `74a4329`, prompt). Falta revisar si las respuestas locales/fichas ofrecen la tienda por su cuenta.
    - **Prueba del dueño en el celular (APK con pasos 1–4, 17:49–17:51):** el registro mostró que `conocer_peces_argentinos` y `habitat` seguían
      yendo a la nube (la detección por palabras no alcanzaba). **Cerrado:** el router ahora también desvía por la intención del motor
      (peces, carnadas, cañas y reeles, nudos, plomadas, boyas, río y las fichas `como_/cuando_/donde_/que_sirve_/que_se_/conocer_`) y se
      sumaron palabras (pez/peces, especie, hábitat, veda, cupo, cebo, lombriz). Con eso apareció un **bug del motor local**: un ítem de las
      intenciones dinámicas sin texto rompía con "Null is not a String" ("me trabé un segundo", p. ej. "cuándo es la veda del surubí" si el
      buscador de fichas todavía no estaba listo). Arreglado en las dos copias de ese código (test `el_guia_engine_item_sin_respuesta_test.dart`).
      **Pendiente:** vedas, cupos y medidas mínimas (datos que cambian por provincia y año) hoy reciben una respuesta genérica ("Dejame ver qué
      tengo sobre conservacion… revisá los equipos o manuales"); lo correcto es un "no tengo ese dato" fijo que mande a la autoridad de pesca
      de la provincia. Hay que decidir el texto con el dueño.
    - **Supabase `guia_conocimiento_distribuido` (captura del dueño, 36 filas, todas `aprobado = FALSE`):** el aprendizaje automático sí había
      guardado cosas hoy (como_pescar_mojarra con datos de jigs y líneas, condiciones_pesca con "el nivel del río…", como_armar_mojarrero,
      etc.), pero **ninguna está aprobada**, así que no llegan a los celulares ni al contexto de la nube. Con el flag nuevo ya no se agregan
      filas. Falta revisarlas y borrar las inventadas (con OK del dueño). Dónde se enseña: Admin → Sistema → Formación → "El Guía Educador"
      (aprobar pendientes y "Enseñarle esto al Guía" sobre las carencias, que escribe `fuente = admin_manual`). **Falta** un modo de enseñar
      cómodo desde el chat del Guía para el dueño (hoy "aprendo" en el chat no guarda nada).
    - **Prueba del dueño con el APK final de la sesión (18:12–18:16, APK `b6d6b97`):** 4 preguntas de pesca → motor local, 1 de charla → nube; 0 líneas
      de aprendizaje; 0 errores del micrófono; memoria 365 MB. Nuevo en el registro (no es de la IA): `Error en el traspaso a tablas legadas:
      PostgrestException … Could not find the 'referido' column of 'pescadores' (PGRST204)`: el código escribe una columna que no existe en
      Supabase; revisar con el esquema de `pescadores`.
    - **Push hecho el 2026-10-07 (OK del dueño):** 15 commits, de `c564a36` (R.1) a `2f316e2`, a `origin/fase-0-contencion`, sin `--force`.
      Lo que quedó sin commitear es el trabajo ajeno de antes (cientos de archivos) y no se subió.
    - El asistente se **apaga solo** después de estar dormido un rato (queda en "desactivado" y hay que volver a prenderlo desde Mi
      Identidad Pescador); también al reinstalar. Decidir si debe quedar prendido.
    - **HECHO (acciones del robot, pedido del dueño):** el robot cumple órdenes con sus GIFs, sin nube ni IA ("tomá mate", "sentate y escuchá",
      "reíte", "ponete furioso/triste", "saludá", "dormite", "despertate", "pensá", "jugamos a las cartas", "hacé el OK"). Tabla editable:
      `assets/elguia/acciones_robot.json` (frases, estado y lo que dice); detector `lib/services/guia_acciones_robot.dart`; flag
      `guia_acciones_robot`. Solo si la frase es TODA la orden (así "cómo se toma mate" o "pensá en una carnada…" siguen siendo preguntas);
      el router lo consulta DESPUÉS del portón de seguridad y del modo emergencia. Tests `guia_acciones_robot_test.dart`. Pendiente: probar con
      la voz en el celular (STT puede entender mal), y decidir si "sentate y escuchá" debe además dejar el micrófono abierto en modo solo-escucha.
      Nota: "desaparecé/hacé un rayo" NO es una acción (es la animación de apagarse).
      **Hallazgo de la 1.ª prueba (18:44):** las órdenes escritas o dichas en el chat de la pestaña "El Guía" contestaban pero el robot flotante
      no cambiaba: `chat_unificado_screen.dart` llama al router y descarta `gifSugerido`. Arreglo: el router publica el pedido en
      `GuiaAccionesRobot.pedida` y el overlay lo escucha (`_onAccionRobot`), venga de donde venga la orden. Los otros chats
      (`chat_asistido_screen.dart`) también pasan por el router, así que quedan cubiertos.
      **2.ª prueba (18:57–19:02):** el dueño habla NATURAL ("hola guía, cómo estás, me gustaría saber si podés tomar mate"), no con órdenes
      secas; algunas órdenes se cumplían y otras no, y en algunas la nube "se negaba". Arreglo: pedidos dentro de una frase más larga
      (`pedidos` + `marcadores_pedido` en la tabla: "podés…", "quiero que…", "me gustaría que…", sin negación y con casi nada después; "cómo
      tomar mate" o "pensá en una carnada…" siguen siendo preguntas), y el prompt de la nube ya no se niega ante una gracia de robot.
      Registro `[DIAG_PREGUNTA]` (solo APK de prueba) para ver la frase exacta. Tip: `adb logcat -G 16M` (el buffer de 256 KB se pisa rápido).
    - **Admin → Importación / Exportación (pedido del dueño, 2026-10-07):** casilla "Seleccionar todos" (tres estados) en la pestaña Exportar. La lógica
      está en `lib/utils/seleccion_catalogo.dart` (con test, commiteada). El cambio de la pantalla está en `lib/screens/admin_importacion_screen.dart`,
      que **sigue sin commitear entera** (es un archivo nuevo del trabajo anterior; HEAD ya lo importa desde `main.dart`): hay que revisarlo y
      commitearlo. Para verlo en app.elguiaya.com falta recompilar el bundle web (`public/`) y publicarlo: necesita OK del dueño.
    - **Excel para Meta / catálogo de WhatsApp Business (pedido del dueño, 2026-10-07):** `lib/services/exportacion_meta.dart` (con
      `test/exportacion_meta_test.dart`, 29 tests) arma el Excel con las columnas del feed de Meta (id, title, description, availability,
      condition, price "55000.00 ARS", link, image_link, additional_image_link, brand, product_type); las imágenes van como enlaces. Valores por
      defecto a confirmar con el dueño: marca "El Guía YA" y enlace `https://www.elguiaya.com/#/producto/<id>`. Botón "Excel Meta / WhatsApp
      Business" en la pantalla (archivo `admin_importacion_screen.dart`, sin commitear entero). Archivo de prueba generado con los 78 productos
      reales: `build/exportacion_meta/catalogo_meta_whatsapp.xlsx` (no se commitea). Revisar: producto "Reel Frontal Kushiro Limay-3000" a $1;
      9 productos sin stock (salen como "out of stock"). Las columnas salen de guías de terceros: confirmar con la plantilla de Commerce Manager.
    - **Seguridad, a revisar:** las imágenes de los productos viven en el bucket de Supabase Storage `documentacion_privada` y se abren sin
      sesión (URL pública). Con ese nombre, verificar que NO haya documentos privados de usuarios en un bucket público.
    - **Etapas 1 y 2 del catálogo de Meta (hechas en el código, SIN publicar/desplegar):**
      · Feed automático: función `supabase/functions/feed-meta/` (CSV de solo lectura, productos activos y con imagen, clave anónima, `verify_jwt = false`,
        caché 1 h, marca y enlace fijos). Reglas compartidas con el Excel mediante `test/fixtures/feed_meta_casos.json` (8 casos; Dart y TypeScript dan lo
        mismo). Tests: `node --test supabase/functions/feed-meta/feed_meta.test.ts` (21). **Falta desplegarla (necesita OK del dueño)**; dirección:
        `https://ymgsxwfwntbqvguvbhoa.supabase.co/functions/v1/feed-meta`. Los tests del lado TS se escribieron junto con el código (no se vieron en rojo antes).
      · Pantalla de exportación: marca y enlace base editables (se guardan), botón "Excel Meta", dirección del feed con botón copiar, panel desplazable.
        Se commitea el módulo entero de importación/exportación (`admin_importacion_screen.dart`, `exportacion_service.dart`, `importacion_service.dart`,
        `utils/web_download*.dart`: eran archivos sin versionar que `main.dart` ya importaba). **Sin verificar visualmente** (hay que mirarlo con el admin).
      · Pendiente: recompilar y publicar la web (`public/`) para verlo en app.elguiaya.com (necesita OK del dueño).
    - **Meta AI confundió el canal:** el dueño subió el Excel a un chat con un asistente de Meta que lo guardó en su sección "Conocimiento" (no en el catálogo) y
      pidió las fotos una por una. El catálogo se carga desde Commerce Manager (Fuentes de datos → Feed de datos), subiendo el archivo o con la dirección del feed.
    - **SEGURIDAD CRÍTICA (hallada 2026-10-07, SIN corregir):** `public.productos` tiene la política `Admin full access productos` con `cmd = ALL`, `roles = {public}`
      y `qual = true`: cualquiera con la clave anónima (que va en la app web) puede **insertar, modificar o borrar productos**. Corregir con una migración que la
      elimine (la política `Admins gestionan productos` ya cubre a los administradores), probando antes que el panel de admin siga funcionando (revisar que el JWT
      del admin traiga `role`/`rol` = admin). Necesita OK del dueño (migración en producción). Revisar también otras tablas con el mismo patrón.
    - **SEGURIDAD `productos` CORREGIDA (2026-10-07, OK del dueño):** migración `20261007200000_productos_cerrar_escritura_publica.sql` (aplicada en producción con
      `apply_migration`): `descontar_stock_pedido()` pasa a SECURITY DEFINER (el disparador de stock corría con los permisos del comprador y dependía de la política
      abierta; de paso se arregla el stock de variantes), se borra "Admin full access productos" (ALL, public, true) y "Admins gestionan productos" pasa a usar
      `public.is_admin()` (la anterior miraba claims `role`/`rol` que el token no trae). Probado antes en una transacción deshecha (anónimo: antes UPDATE=1, después
      UPDATE=0, DELETE=0, INSERT bloqueado 42501; lectura pública 78 productos; admin@elguiaya.com UPDATE=1; usuario común 0) y verificado después en producción.
      Quedan las políticas de lectura pública. Sin probar en la app real: entrar como admin y editar un producto, y hacer una compra de prueba (stock baja).
    - **SEGURIDAD, MÁS AGUJEROS (SIN corregir, urgente):** políticas con `roles = {public}` y `true` que dejan escribir a cualquiera con la clave anónima:
      `pagos` (INSERT y UPDATE), `pedidos` ("Admin gestiona pedidos", ALL), `categorias` y `rubros` (ALL), `envio_domicilio` (ALL), `solicitudes_contacto` (UPDATE),
      `recordatorios` (UPDATE), `guia_conocimiento_distribuido` y `guia_capacitacion` (INSERT: cualquiera puede meter "conocimiento" al Guía), `pedido_items`
      (INSERT; y SELECT público de todos los ítems), `notificaciones`/`notificaciones_globales`, `logs_admin`, `tickets`, `eventos_web`, `descargas_app`,
      `papelera_*`, `webhook_logs` (INSERT). Algunas son legítimas (formularios públicos, eventos), pero `pagos`, `pedidos`, `categorias`, `rubros`,
      `envio_domicilio` y la tabla del Guía hay que cerrarlas con el mismo método: probar en transacción deshecha, revisar quién escribe (disparadores sin
      SECURITY DEFINER, Edge Functions con clave de servicio) y migrar con OK del dueño. Un paso por tabla.
    - **SEGURIDAD `pagos` y `pedidos` CORREGIDAS (2026-10-07, OK del dueño):** migración `20261007210000_pagos_pedidos_cerrar_escritura_publica.sql` (aplicada con
      `apply_migration`). Antes: un ANÓNIMO leía los 5 pedidos (dirección, CUIT/DNI, ids de Mercado Pago) y cualquier usuario con sesión los leía y modificaba;
      `pagos` dejaba crear, cambiar y leer a cualquiera. Ahora: pedidos solo para sus participantes (usuario_id, pescador_id, cliente_id, capitan_id) y admin
      (`is_admin()`); pagos para su dueño y admin. Los viajes se crean con `pescador_id` (los 5 pedidos tienen `usuario_id` nulo), por eso la política de crear
      reconoce pescador y cliente. Las Edge Functions de Mercado Pago usan la clave de servicio (no pasan por RLS). Probado antes en transacción deshecha y
      verificado después en producción (anónimo 0/0/0; ajeno logueado 0/0; pescador 1/1; capitán 1/1; admin 5/1). **Sin probar en la app real:** flujo de viaje
      (aceptar presupuesto, iniciar, finalizar, calificar), carrito/checkout (NO comprar: Mercado Pago está en producción) y panel de pedidos del admin.
    - **Pendiente de esta tanda:** (1) un participante todavía puede cambiar columnas sensibles de SU pedido (`estado`, montos, `mp_*`): falta un disparador que
      lo limite (el cliente hoy confirma el pago desde la app: `confirmarPagoPedido`); (2) `pedido_items` (SELECT público de todos los ítems; INSERT abierto);
      (3) `categorias`, `rubros`, `envio_domicilio` (ALL abiertas), `guia_conocimiento_distribuido` / `guia_capacitacion` (INSERT abierto), `solicitudes_contacto`
      y `recordatorios` (UPDATE abierto); (4) el cliente guarda pagos con una columna que no existe (`cliente_id` en `pagos`): código muerto de `pago_service.dart`.
    - **COLUMNAS SENSIBLES DE `pedidos` LIMITADAS (2026-10-07, OK del dueño):** migración `20261007220000_pedidos_proteger_columnas.sql` (aplicada): disparador
      `trg_pedidos_proteger_columnas` (BEFORE UPDATE) que impide a un participante cambiar: capitan_id / pescador_id / cliente_id (usuario_id solo para ponerse a sí
      mismo), cierre_manual_* y admin_observaciones, tracking_* / despachado_at / entregado_at, estado_logistico a algo que no sea pendiente_pago / preparando /
      sin_envio, y —con un pago APROBADO registrado— mp_payment_id, monto_total, total, tarifa_envio, envio_tarifa_monto, envio_tarifa_id. Pasan: administradores
      (`is_admin()`), clave de servicio, funciones SECURITY DEFINER y migraciones (solo se vigila a los roles `authenticated`/`anon`). Probado en transacción deshecha
      y verificado en producción. Un pago rechazado no congela el importe (se puede reintentar).
    - **LO QUE TODAVÍA NO SE PUEDE CERRAR (decisión del dueño):** `estado` y los datos `mp_*` de un pedido SIN pago aprobado siguen siendo escribibles por el
      participante, porque hoy **la confirmación de un pago la hace la app del cliente** (`confirmarPagoPedido` en `viaje_lifecycle_service.dart`) y `webhook_logs`
      tiene **0 filas**: el webhook de Mercado Pago (`mp-webhook`) nunca procesó nada (no está desplegado/registrado, o falta su secreto). Un cliente modificado podría
      marcar su pedido como pagado sin pagar. Para cerrarlo: (1) desplegar `mp-webhook` y registrar su URL en Mercado Pago (hay que usar el secreto en Supabase, nunca
      en el chat); (2) hacer que la confirmación la aplique el servidor (extender `consultar-pago-mp` o confiar en el webhook) y que la app solo consulte el estado;
      (3) recién ahí bloquear `estado` y `mp_*` en el disparador. Mercado Pago está en producción: probarlo antes en sandbox. `crear-preferencia` ya toma el importe de la
      base con un piso (`total_minimo_pedido`), no del cliente.
    - **SEGURIDAD `pedido_items`, `categorias`, `rubros`, `envio_domicilio` CORREGIDAS (2026-10-07, OK del dueño):** migración
      `20261007230000_pedido_items_catalogo_cerrar_escritura_publica.sql` (aplicada). Antes un anónimo leía los ítems de todos los pedidos y las direcciones de entrega
      (nombre, teléfono, correo, dirección) y modificaba categorías y rubros. Ahora: categorías y rubros se leen públicamente y los escribe solo un admin
      (`is_admin()`); `envio_domicilio` solo su dueño y admin; `pedido_items` los ven los participantes del pedido (usuario, pescador, cliente y capitán) y los crean
      usuario/pescador/cliente (los viajes tienen `usuario_id` nulo); admin todo. Probado en transacción deshecha y verificado en producción. **Sin probar en la app real:**
      el carrito/checkout (no comprar: Mercado Pago en producción), la pantalla de viajes programados (lee los ítems) y el panel de administrador de categorías.
    - **Todavía abiertas (INSERT/UPDATE con `true` para `public`), por prioridad:** `guia_conocimiento_distribuido` y `guia_capacitacion` (INSERT: cualquiera mete
      "conocimiento" al Guía), `solicitudes_contacto` (UPDATE: "Edición para capitanes" sin condición), `recordatorios` (INSERT/UPDATE `_service` sin condición),
      `notificaciones` y `notificaciones_globales` (INSERT: cualquiera puede mandar notificaciones a cualquiera), `webhook_logs` (INSERT: se podrían falsificar
      registros del webhook), `logs_admin`, `tickets`, `eventos_web`, `descargas_app`, `papelera_archivos`, `papelera_cotizaciones` (INSERT; varias son formularios o
      métricas legítimos y se pueden dejar con límites). Un paso por tabla, mismo método.
    - **Catálogo de Meta publicado (2026-10-07):** el dueño cargó `catalogo_meta_whatsapp.csv` en Commerce Manager del portfolio RIO NEGRO PESCA (catálogo "Artículos llegados",
      origen "Nueva lista de datos": 78 productos, 0 problemas al subir; quedaron además 30 viejos cargados a mano, con ids cortos). El número de WhatsApp Business del dueño
      (11 3818-7012) está en la app del celular, vinculado a la cuenta "rionegropesca", NO a "elguiaya": el catálogo se conecta desde la app (Herramientas → Catálogo →
      Ajustes → Conectar catálogo). No registrar ese número en la API (lo saca de la app). **Pedido del dueño:** el enlace de cada producto va a `www.elguiaya.com`, no a
      `app.elguiaya.com`; cambiado en Excel, función `feed-meta`, pantalla y tests (el CSV se regenera con `build/exportacion_meta/generar_csv.mjs`; falta confirmar que
      `https://www.elguiaya.com/#/producto/<id>` abra el producto). Pendiente: revisar los 111 "problemas" que marca Meta, el producto a $1 y los 8 agotados.
    - **Enlaces del catálogo de Meta (corrección, 2026-10-08):** `elguiaya.com` es un sitio aparte (repo propio en Vercel) y solo se ve la ruta `/tienda`; no hay páginas por
      producto confirmadas. Los enlaces `/#/producto/<id>` eran de la app y no llevaban a ningún lado. Ahora todos los productos llevan a `https://elguiaya.com/tienda` (enlace fijo;
      `ExportacionMeta` y `feed-meta` aceptan `{id}` o una base terminada en `/` si el sitio tiene páginas por producto). Falta que el dueño suba el CSV nuevo a Meta (se pisan por
      id) y, si el sitio tiene páginas por producto, pasar su ruta. El prompt del Guía todavía menciona enlaces `elguiaya.com/#/tienda`, `/#/mapa`, `/#/clima`: revisar.
    - **TIENDA `elguiaya.com/tienda` ROTA (hallazgo 2026-10-08, causa anterior a mis cambios):** la página pide productos, categorías, banners y blog juntos; el blog falla para el
      visitante (`permission denied for table profiles`) porque su política de lectura consulta `profiles`, que la Fase 2 de seguridad (`20261001000000`) cerró al anónimo. Resultado:
      "Error al cargar la tienda" para todos. Probado como visitante: productos 78 OK, categorías 11 OK, banners 2 OK, blog ERROR. Arreglo escrito y probado en transacción deshecha
      (`supabase/migrations/20261008010000_blog_lectura_publica_sin_profiles.sql`: visitante lee artículos activos; admin sigue leyendo todo): **FALTA APLICARLO (necesita OK del dueño)**.
      Otras políticas públicas que consultan `profiles` (recordatorios, webhook_logs, calificaciones_viaje, transacciones_capitanes, tickets) no afectan a la tienda.
      Además `elguiaya.com/tienda` redirige a `https://www.elguiaya.com/` (el dominio canónico es www).
    - El avatar viene **apagado** tras instalar (interruptor en Mi Identidad Pescador): confirmar si es lo deseado.

0. **Fase R, R.1 hecho (informe en `docs/INFORME_MEMORIA_R1.md`):** la app llega a 700–1160 MB y Android la cierra en primer plano; el
   65–70 % es **memoria gráfica** que crece ~5 MB/s en reposo. Descartados con datos: motor gráfico (Skia = Impeller), heap de Dart
   (41 MB), caché de imágenes de Flutter (73 MB, quieto), avatar visible y arranque del Guía. **Sin atribuir**: GIFs del avatar
   (~1,1 GB decodificados), `IndexedStack` que construye las 4 pestañas a la vez + 112 `Image.network` sin `cacheWidth`, y
   `BackdropFilter`. **Siguiente: R.3 empieza con 3 versiones de diagnóstico** (sin GIFs / pestañas perezosas / sin desenfoque).
   Hallazgos aparte (de la misma prueba): la voz se corta porque Android mata el servicio de voz de Google; el cartel dice "Offline"
   con el chat "IA Cloud · ONLINE"; la nube inventó "Según el parte oficial… el nivel del río está medio" (rompe la regla 2).

0. **PRIORIDAD: Fase R (rendimiento en gama baja), en `docs/PLAN_AYUDANTE_IA.md`.** Prueba real en el Moto G15
   (2026-10-07, APK release instalado por cable): el Guía tarda ~12 s en arrancar y congela la app; la app usa
   ~820 MB y Android termina cerrándola por falta de memoria. Va **antes** de la Fase 2.
   Otros errores vistos en el registro del celular (fuera del Guía): permisos denegados en `profiles`,
   `config_sistema` y `vista_configuracion_branding` (la app no está adaptada a la seguridad nueva de la base);
   falta la función `get_mp_public_config` y la columna `pescadores.referido`; cierre por *null check* en
   `bienvenida_definitiva_screen.dart:392` al iniciar sesión; y **el login fallido escribe en el registro el correo
   y el largo de la contraseña** (sacarlo).

1. **El dueño pega sus preguntas** en `test/eval/preguntas_dueno.txt` (una por línea, tal cual le salen; ideal 150 a 200). Se corre
   el runner, se le devuelve `build/eval_guia/revision_dueno.md` para marcar ✔/✘, y recién ahí hay preguntas de pesca reales con
   etiqueta (2.3) y se puede **calibrar el buscador** de verdad (2.4). Con las de plantilla no hay nada que calibrar: el top-1
   no depende de los umbrales (`EVAL_SWEEP=1`).
2. **APK de prueba en el Moto G15** del dueño (`docs/GUIA_APK_PRUEBA.md`; falta Java 17) y **1.2c parte 3**, la prueba de oído.
3. **OK del dueño** para aplicar `supabase/migrations/20261006100000_guia_registro_anonimo.sql` y escribir el subidor (flag
   `guia_registro_anonimo`, aviso y opción de no participar antes del lanzamiento). Hasta entonces: exportar el CSV a mano.
4. Fase 2.3 completa: 40 transaccionales, 40 multiturno, 30 dictadas en el celular, 20 de temas mezclados (hoy hay 10, 0, 0, 0).
5. 1.7 (opcional). Después: Fase 3, Fase 4 (voz y micrófono, palabra de activación "Baqueano"), Fase 5 (opcional).

## Pendientes que dependen del dueño

- **(2026-10-07) Supabase "EXCEEDING USAGE LIMITS": CONFIRMADO, es "Cached Egress": 16,3 GB de 5 GB (327 %).** Todo
  lo demás está bien (egress 0,24/5 GB, storage 0,5/1 GB, base 0,05/0,5 GB, funciones 11/500.000). Casi todo es del
  **7 de octubre**: los 3 videos de banners se pidieron **15.843 veces** ese día porque el reproductor los vuelve a
  descargar en cada vuelta del bucle (ver R.3b). Ciclo 14-sep → 14-oct: hasta el 14 de octubre la organización
  sigue excedida y Supabase **puede restringir el proyecto (402)**. Mitigación inmediata propuesta: desactivar los 3
  banners de video (`banners_promo.activo = false`, reversible) hasta que R.3b descargue cada video una sola vez.
  **HECHO 2026-10-07 con OK del dueño (Opus):** desactivados los banners id 30 y 27 (hero) y 25 (bottom), los únicos
  `.mp4`. Los archivos siguen en Storage; se reactivan desde el panel de banners **después** de R.3b. El contador de
  Cached Egress no se puede bajar: vuelve a cero el 14-oct. Verificado en `edge_logs`: las 15.843 descargas
  ocurrieron todas entre las 16:32 y las 18:57 UTC del 7-oct (las pruebas de la Fase R con el APK con video); desde
  ahí no hubo ninguna más.
  **Cómo seguir con los videos (decidido con el dueño):** ahora, R.3b (cada celular descarga cada video **una vez**
  y lo reproduce desde disco) + videos más livianos (720p, sin audio, 5–8 s, ~300–500 KB). Con eso, 5 GB/mes
  alcanzan para ~1.500 usuarios aunque los banners cambien todos los meses. **Más adelante, con usuarios reales:**
  mover videos e imágenes de la tienda a un almacenamiento sin costo de descarga (p. ej. Cloudflare R2; confirmar
  condiciones vigentes), subiendo los archivos a través del servidor, nunca con claves en la app.
- **No aprobar en bloque** las 36 propuestas de `guia_conocimiento_distribuido`: hay basura, duplicados y datos
  sensibles (ver Fase 3.5 del plan).

- **No repartir APK** (sí instalar en el propio celular, ver `docs/GUIA_APK_PRUEBA.md`) hasta evaluar el mal ranking del buscador (ej. "masa para boga" devuelve las empanadas) y las
  11 de 50 fuera de tema (Fase 2). La voz ya lee bien las unidades (1.2b).
- **Desplegar `ia-proxy`** (cambio del 1.5) y correr `scripts/probar_groq_rapido.mjs` con `SUPABASE_URL` y
  `SUPABASE_ANON_KEY` cargadas en su sesión (sin pegarlas en el chat): mide el p50 y las respuestas cortadas. Si no
  es más rápido, apagar `guia_groq_rapido`.
- **Push:** hecho el 2026-10-06 (36 commits). Cada push nuevo necesita el OK del dueño. Ojo: `scripts/scan_secrets.ps1` falla en esta PC (error de `rg` con un patrón PCRE2), así que el workflow de GitHub podría no escanear bien; se revisó a mano el diff.
- Medir en el **Moto G15** (equipo de referencia: **4 GB de RAM** (3,6 GB visibles), **Android 15**, verificado
  por `adb` el 2026-10-07; depuración USB ya autorizada en la PC del dueño): mensaje "Retriever listo… en N ms" (< 2000);
  respuesta offline p95 < 300 ms (1.4); hora/luna/clima en modo avión < 300 ms (1.0b).
- Probar en el Moto G15 sus **preguntas reales** de seguridad, con señal y en modo avión.
- **Persona idónea** (médico, guardavidas, Cruz Roja) revisa los textos marcados `// REVISAR: persona idónea`.
  Incluye el texto nuevo de salud sin emergencia (`primeros_auxilios.json` → `salud_sin_emergencia`).
- Confirmar con **Prefectura** que 106 y canal 16 valen para todas las zonas de uso.
- Elegir la mejor **voz en español** instalada en el celular (paso 5.V.0).

## Otros frentes abiertos (fuera del ayudante)

- **Pagos (Mercado Pago):** en **modo producción** (comprar cobra plata real). Hay migraciones y funciones
  preparadas sin aplicar; el modelo de cobro de viajes (comisión con pago dividido) está **en pausa** hasta la
  respuesta de Mercado Pago a una consulta del dueño. No avanzar sin su OK.
- **Comisión de la plataforma (2026-10-03): el 10 % actual NO es definitivo.** En otra app el dueño calculó que
  hace falta al menos ~17 % + IVA para ganar algo con Mercado Pago, pero ese cálculo suponía que todo el dinero
  pasa por su cuenta. Con pago dividido, la comisión de Mercado Pago se le descuenta primero al capitán. Pendiente:
  1. **Dueño + contador:** porcentaje mínimo para el modelo de pago dividido (monotributo: IVA de las comisiones
     de Mercado Pago no recuperable, retenciones de ingresos brutos).
  2. **Dueño decide quién paga la comisión:** encima del precio del capitán (el pescador), descontada del capitán,
     o mixta. Afecta las ofertas en la subasta.
  3. **Código, después de 1 y 2:** hoy el 10 % está escrito a mano en `lib/screens/resumen_reserva_screen.dart`
     (líneas ~153 y ~275) y **se calcula en el celular**. Pasarlo a **un solo valor configurable** desde el panel
     de admin y **calcularlo en el servidor** (Edge Function `crear-preferencia`), nunca confiando en el monto
     que manda la app. También está fijo en `supabase_service.dart` (~línea 4779, cálculo de comisionistas).
     **No existe hoy un regulador de comisión de viajes en el admin.** El único deslizador parecido es el
     "Remarcador" de la tienda (`admin_remarcador_screen.dart`), que sube precios de productos, no comisiones.
     **Diseño acordado:** regulador en el admin → valor en la configuración del sistema (solo admin escribe) → la
     función del servidor lo lee en cada cobro y manda el monto a Mercado Pago como `marketplace_fee` /
     `application_fee` (Mercado Pago no guarda el porcentaje: se envía en cada pago). **El porcentaje se congela en
     cada viaje al aceptar el presupuesto**: cambiar el regulador no afecta viajes ya aceptados, ni sus
     liquidaciones ni las comisiones de los referidos.
- **Comisionistas (referidos) y Mercado Pago:** el reparto de `supabase_service.dart` (~línea 4790: 100 % de la
  comisión si trajo a los dos, 70 % si trajo al capitán, 20 % si trajo al pescador, solo primer viaje y dentro de
  30 días) necesita un **tercer receptor** en el pago. El pago dividido simple de Mercado Pago reparte entre dos
  (capitán + plataforma); el reparto entre varios es solo por su equipo comercial. Opciones: preguntarlo a Mercado
  Pago (sumarlo a la consulta pendiente), pagar en crédito o descuentos dentro de la app, o un premio fijo como gasto
  del dueño. **No** pagar a mano por fuera (riesgo fiscal que el dueño quiere evitar). Revisar también los
  porcentajes si la comisión sube.
- **Seguridad de Supabase:** quedan lecturas directas de `profiles` (`docs/TAREA3_INVENTARIO_PERFILES.md`),
  tablas con RLS sin políticas, funciones RPC que la app llama y no existen en producción.
- **Antes del lanzamiento:** bucket de documentación privado con URL firmadas, limpiar usuarios, pedidos y
  archivos de prueba (con respaldo), avisar sobre el registro anónimo de preguntas y dar opción de no participar.

## Problemas conocidos

- Los archivos de registro que **ya existen en los celulares** (antes del 2.1) conservan el formato viejo: con hora y sin limpiar. Si
  se exportan, hay que borrarlos primero ("Borrar el registro de este celular").
- El anonimizador no detecta un nombre dicho sin "me llamo" o "soy" ("pasale el mensaje a Carlos").
- Las respuestas de **primeros auxilios** recibieron solo correcciones de tildes (1.2c); siguen marcadas
  `REVISAR: persona idónea`. Quedan 9 palabras ambiguas revisadas a mano y dejadas como están (ver el script).
- 11 de 50 preguntas fuera de tema todavía reciben una respuesta de otra cosa (eran 17; lista y causas en
  `test/guia_no_se_test.dart`, constante `conocidas`; meta: 0). Con el 1.3b se perdieron 0 de 21 aclaraciones
  válidas del conjunto de validación, pero ese conjunto es de plantilla: puede subestimar la pérdida real.
- El buscador (BM25) rankea mal algunas preguntas: "cómo se prepara la masa para boga" da la receta de empanadas
  (test salteado en `test/el_guia_engine_retrieval_test.dart`). Umbrales sin calibrar: Fase 2.
- La pantalla de pronóstico y el mini widget del panel **escriben** el caché del clima pero todavía no lo **leen**
  cuando falla la red (1.0b).
- Antes del 1.5, **toda respuesta de la nube con tilde fallaba** (el proxy codificaba en latin1) y caía al motor
  offline. Ya está arreglado, pero en la práctica la nube casi no se estuvo usando: medir con tráfico real.
- **Java:** la PC no tiene Java 17 y `android/gradle.properties` (cambio local sin commitear) apunta a
  `C:\Program Files\Eclipse Adoptium\jdk-17.0.20.101-hotspot`, que no existe: `flutter build apk` falla ahí.
- `HEAD` no compila solo en una copia limpia: `cart_persistence_service.dart` importa `models/tipo_checkout.dart`, que
  no está commiteado (ajeno al ayudante).
- "Estoy perdido, no sé qué caña comprar" se toma como emergencia: costo aceptado de "ante la duda, seguridad".
- `README.md` desactualizado en la parte de IA.
