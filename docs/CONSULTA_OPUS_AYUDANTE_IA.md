# Consulta para Opus — Rediseño del ayudante IA "El Guía" (modo sin señal)

> Documento autocontenido. Está pensado para pegárselo entero a Opus (o dárselo junto con el repo).
> Quien lo redactó revisó el código leyendo archivos; **no ejecutó la app ni midió calidad real**.
> Lo que no se verificó está marcado como **[NO VERIFICADO]**.

---

## 1. Qué te pedimos

Queremos un **proyecto concreto, por fases y medible** para modernizar "El Guía", el ayudante IA de nuestra app,
con foco en que **cuando el teléfono no tiene señal se comporte más como una IA de verdad** y menos como un buscador de
frases hechas. Hoy "a veces anda bien y otras medio medio".

No queremos una lista de ideas sueltas. Queremos:

1. **Un diagnóstico propio**: confirmá o corregí lo que describimos abajo leyendo el código que indicamos.
2. **Un plan recomendado** (una sola opción principal, con la alternativa descartada y por qué), dividido en fases
   cortas, cada una con una **puerta de salida medible** (qué se mide, con qué conjunto de prueba, qué umbral).
3. **Para cada fase**: archivos a tocar o crear, riesgos, cómo se revierte, y cuánto trabajo estimás.
4. **Qué NO hacer** (incluidos los callejones sin salida que ya recorrimos, sección 6).
5. **Preguntas que nos tenés que hacer a nosotros** antes de empezar, si algo cambia tu recomendación.

Al final damos el formato de respuesta que preferimos (sección 9).

---

## 2. Contexto del producto y restricciones reales

- **La app**: Flutter (Android + web). Marketplace de viajes náuticos de pesca (pescadores contratan capitanes) + tienda +
  el ayudante "El Guía". Público: pescadores argentinos del Paraná, islas y costa. Español rioplatense.
- **Equipo**: una sola persona (el dueño, monotributista), **sin presupuesto** para infraestructura pagada. Todo lo que
  se proponga tiene que poder correr gratis o casi gratis, y poder mantenerlo una persona.
- **Backend**: Supabase **plan Free** (proyecto `CapitanYA-MASTER`). Hoy muestra el aviso *"Grace period is over — projects
  will not be able to serve requests when you use up your quota"*. **La cuota se está agotando**, o sea que cualquier cosa
  que dependa de Supabase puede dejar de responder. Storage Free: tope de 50 MB por archivo. [Ancho de banda: NO VERIFICADO]
- **Usuarios hoy**: todos son de prueba (nadie externo conoce la app todavía). Esto es una ventaja: se puede cambiar mucho
  antes del lanzamiento.
- **Contexto de uso**: gente en el río/mar, a menudo **sin señal o con señal mala**, con una mano ocupada, a veces con
  urgencia. La voz importa (hay TTS y reconocimiento de voz).
- **Dispositivos objetivo** y RAM mínima: **[NO VERIFICADO]** — no tenemos relevamiento de qué celulares usan. Por favor
  planteá el diseño con tres perfiles de equipo (gama baja 3–4 GB, media 6 GB, alta 8+ GB) y decinos cómo degrada.

### Regla innegociable de seguridad
Todo lo de **emergencia, primeros auxilios, "estoy perdido", frecuencias VHF/Prefectura Naval, GPS y lo transaccional de la
app (crear viaje, pagar, cotizaciones…)** sigue **100% en el motor de reglas determinista**. **Nunca** lo responde un modelo
generativo. *(CORRECCIÓN posterior a la revisión de Opus: esto NO está implementado de punta a punta. `_intencionesReservadas`
solo protege al buscador offline; con señal, el router manda esas consultas a Groq. Ver Fase 0 del plan de Opus.)* Cualquier
plan tiene que respetar esto y, si propone un generativo offline, tiene que explicar cómo garantiza que no se cuela en esos temas.

---

## 3. Cómo está armado hoy (leído del código)

### 3.1 El router de 5 niveles (`lib/services/baqueano_ia_service.dart`, `BaqueanoIAService.responder`)

| Nivel | Qué hace | Dónde |
|---|---|---|
| Pre-filtros | Diagnóstico de conexión, detección de enojo/tristeza (listas de frases fijas), filtro de temas prohibidos (dinero, reembolso, CBU…) | `baqueano_ia_service.dart` |
| 0 — Acción directa | Si sabe en qué pantalla está el usuario, ejecuta la acción sin IA (<5 ms). También responde precio/descripción del producto en pantalla | `CopilotActionService`, `GuiaCopilotBrain` |
| (Tienda) | Búsqueda de producto en el catálogo local por conteo de coincidencias | `_buscarProductoEnConsulta` |
| 2 — Nube | **Groq** (modelo `openai/gpt-oss-120b`) vía Edge Function `ia-proxy`. Con prompt de sistema armado a partir de `CapacitacionService` + rol detectado + memoria del usuario + historial de **solo 8 mensajes** | `groq_service.dart`, `ia_edge_function_client.dart` |
| 3 — Offline | `ElGuiaEngine` (motor de reglas + búsqueda en librerías JSON). Se le agrega un **retraso artificial aleatorio de 400–1200 ms** para "parecer que piensa" | `el_guia_engine.dart` |
| 4 — Contingencia | Frase de error genérica ("me trabé un segundo…") | `baqueano_ia_service.dart` |

Datos importantes del router:
- Decide "online" solo con `modoOnline && conectado && GroqConfig.tieneApiKey`. `tieneApiKey` **siempre es `true`**
  (las claves se movieron al servidor), así que **no sabe si el proxy realmente responde**. Si la conexión existe pero el
  proxy falla o tarda, espera hasta **12 s** y recién ahí cae al offline.
- `ConnectivityBridge.estaConectado` mide si hay red, no si hay **internet útil** ni si Supabase está vivo.
- El "modo online/local" lo puede forzar el usuario a mano (toggle) y se guarda en `SharedPreferences`.
- Cada respuesta pasa por `GeminiLearner.evaluarYGuardar` (ver 3.4).

### 3.2 El motor offline (`lib/services/el_guia_engine.dart`, **4476 líneas**)
- Detección de **intenciones** por palabras clave y sinónimos (`detectarIntenciones`, `evaluarConfianza`, umbrales por
  categoría escritos a mano: 0.50 charla, 0.75 app, 0.85 pesca, 0.90 seguridad).
- ~**50 funciones `_responderXxx()`** con respuestas armadas en código (clima, peces, carnadas, nudos, emergencia, Prefectura…).
- **222 librerías JSON** en `assets/elguia/librerias/` (1,1 MB en total), 18 de pantallas de la app en `assets/elguia/app/`,
  más `personalidad.json` y `capacitacion/base_conocimiento.json`. Son respuestas ya redactadas con el tono del "Baqueano".
- Humor contextual (10 % de probabilidad), niveles de "frustración", cierre de charla con frases fijas.
- **Búsqueda dinámica en librerías** por regex de frases de acción ("cómo se prepara", "qué hago…").
- **"Retrieval-first"** (BM25 + índice semántico opcional): **implementado pero APAGADO por defecto**
  (`retrievalFirstHabilitado = false`, línea 76). Se prende por `SharedPreferences` (`guia_retrieval_first`).
  Archivos: `lib/services/guia_retrieval/` (BM25, stemmer español, corpus de fichas, embedder, índice semántico, descarga del modelo).
- El modelo de embeddings previsto es `multilingual-e5-small` en GGUF Q8 (~126 MB) corrido con `llama_cpp_dart 0.9.0-dev.10`
  (prerelease fijado a mano; hay un `.aar` nativo de Android que debe coincidir con esa versión). Solo si hay RAM suficiente
  (`minRamMb` del manifest) y el modelo ya está descargado.
- **Web**: `GuiaEmbedder.plataformaSoportada` deja la capa semántica fuera de web. Offline en web = solo reglas + BM25.

### 3.3 La nube (`supabase/functions/ia-proxy/index.ts`, 106 líneas)
- Proxy a Groq y Gemini (`gemini-2.5-flash`). Claves solo como secretos del servidor.
- Límite de **30 pedidos cada 10 min por token**, guardado **en memoria** de la instancia (se reinicia con cada arranque en frío).
- Tamaño máximo 256 KB. Sin streaming: espera la respuesta completa. Timeout del lado cliente: 12 s.
- Hay un alias de modelo (`llama-3.3-70b-versatile` → `openai/gpt-oss-120b`).
- `GeminiService` (`gemini_service.dart`) existe y solo lo usan **dos pantallas** (`asistente_chat_screen.dart`,
  `asistente_capitanya_screen.dart`), que parecen ser un **segundo camino paralelo** al router principal. **[NO VERIFICADO]**
  si esas pantallas siguen en uso o son código viejo.

### 3.4 Memoria y aprendizaje
- `GuiaMemoriaService`: nombre, especies, zonas, nivel, último tema, etc., en `SharedPreferences` por usuario, con respaldo
  en `profiles.bio_pescador`. Se inyecta como "CONTEXTO DEL USUARIO" en el prompt de Groq (máx. 5 líneas).
- **Bucle de aprendizaje**: el prompt le pide a Groq que, cuando diga algo técnico valioso, agregue `|||APRENDO||| {json}`.
  `GeminiLearner` lo parsea, lo evalúa (puntaje ≥ 6) y lo manda a una "incubadora" (pendiente de aprobación en Supabase).
  Un panel de admin ("educador") aprueba; un GitHub Action nocturno (`consolidate.yml`) consolida en los JSON del repo;
  `GuiaKnowledgeSyncService` y `GuiaOtaSync` bajan conocimiento aprobado a los celulares (con límites por librería y por WiFi).
- Si el usuario corrige ("no es así", "estás equivocado"), borra el último conocimiento aprendido.

### 3.5 Personalidad y UI
- Personaje con GIFs por estado (`hablaConMate`, `exito`, `duda`, `enojado`, `triste`…), `GuiaLocalCore` con parpadeo/bostezo
  (Hive), `IAStatusBadge` que muestra el nivel activo, TTS (`flutter_tts`) y reconocimiento de voz (`speech_to_text`).
- Personalidad definida en `assets/elguia/personalidad.json` y `base_conocimiento.json`: campechano, "chamigo", máx. 3 líneas,
  sin markdown, **nunca decir que es una IA** ("como modelo de lenguaje" prohibido), no hablar de dinero.

### 3.6 Tests existentes
`test/el_guia_engine_v2_test.dart`, `el_guia_engine_retrieval_test.dart`, `el_guia_engine_pna_test.dart`,
`guia_retrieval_test.dart`. **[NO VERIFICADO]** si pasan hoy. No hay un conjunto de evaluación "end-to-end" de calidad de respuestas.

---

## 4. Qué creemos que genera el "anda bien / medio medio" (hipótesis a validar)

1. **Dos "cerebros" muy distintos con una transición brusca.** Online = LLM fluido que razona. Offline = reglas por palabra
   clave. Para el usuario, la misma pregunta puede dar una respuesta brillante o una frase enlatada según haya señal. Eso es
   lo que más se nota.
2. **El offline fabrica "naturalidad" con trucos**: retraso aleatorio de 400–1200 ms, humor al azar, frases de impaciencia/bug
   en listas fijas, 15+ listas de respuestas enlatadas por emoción. Se nota la repetición.
3. **Detección de "online" demasiado optimista**: hay red ≠ hay respuesta. Un proxy lento o caído (cuota de Supabase Free)
   cuesta **hasta 12 s de espera** antes de caer al offline.
4. **Intenciones por palabras clave y umbrales a mano** (~4500 líneas de reglas). Frágil ante variantes de redacción,
   voz transcripta con errores y mezcla de temas en una frase.
5. **El mejor componente offline ya existente está apagado**: BM25 acertó 97,5 % top-1 / 100 % top-3 en 80 preguntas de
   validación (informe `mini_model_lab/PASO1_RETRIEVAL.md`, sep 2026). *(CORRECCIÓN: el informe las llama "reales", pero
   son preguntas generadas por plantilla a partir de los nombres de las librerías, ej. "¿Para qué sirve plomito antes lider?".
   El acierto con preguntas de pescadores reales NO está medido.)* Y sin embargo `retrievalFirstHabilitado = false`.
   **[NO VERIFICADO]** por qué se dejó apagado (¿riesgo de RAM del llama.cpp? ¿falta de decisión? ¿bug?). BM25 solo no necesita llama.cpp.
6. **Historial corto** (8 mensajes) y memoria de usuario mínima; el offline casi no usa el contexto de la conversación.
7. **Sin streaming ni respuesta parcial**: la respuesta aparece de golpe, o no aparece.
8. **Código muy grande y con caminos paralelos** (17.000+ líneas tocan al ayudante; dos pantallas con otro servicio de IA;
   comentarios que todavía dicen "Ollama" cuando ya no existe).

---

## 5. Lo que ya tenemos y se puede reutilizar

- **383 fichas de búsqueda** ya construidas desde las librerías (`mini_model_lab/retrieval/fichas_corpus.json`; scripts
  `construir_fichas.py`, `evaluar_retrieval.py`), 100 % de cobertura de las 181 librerías no excluidas.
- **Conjunto de validación de 80 preguntas (generadas por plantilla, no de usuarios reales)** + 44 preguntas fuera de dominio (`preguntas_fuera_de_dominio.jsonl`) para
  calibrar el "no sé". Base para armar un conjunto de evaluación serio.
- **Pipeline de descarga de modelos por WiFi** con manifest, versión y hash (`GuiaModeloDescarga`, `GuiaOtaSync`).
- **El runtime llama.cpp ya está integrado** en el proyecto (aunque como prerelease frágil).
- **Un `.gguf` de 278 MB** (Gemma 3 270M ajustado) y un LoRA, que **no sirven** (ver 6).
- Un panel de admin para aprobar conocimiento ("educador") y un bucle de aprendizaje funcionando.

---

## 6. Callejones sin salida ya recorridos (no los repitas)

**Fine-tuning de Gemma 3 270M como "redactor" offline — fracasó en cuatro corridas (v1–v4)**, documentado en
`mini_model_lab/FASES.md`. Lecciones verificadas:
- Un modelo de 270M **no memoriza ~800 hechos de pesca** por más cuidado que se tenga; Google lo posiciona para
  clasificación/extracción, no para conocimiento.
- Salían respuestas **inventadas**: palabras inexistentes, una receta de arroz ante una pregunta de pesca.
- El dataset de fondo tenía solo **321 respuestas distintas en 1684 filas** y metadatos internos de la app colados.
- Hubo además bugs de tokenización (`padding_side`, doble BOS) que invalidaron las corridas v1–v4.
- La cuantización a 8 bits **no** fue la causa.

Conclusión que ya adoptamos en su momento: **"retrieval-first"** (buscar la ficha correcta y mostrarla), porque las
respuestas de las librerías ya están escritas con el tono del Baqueano. Lo que **no** resolvimos es **cómo sonar más
conversacional y menos "ficha" sin inventar datos**.

También descartado por tamaño: bge-m3 (542 MB), EmbeddingGemma-300m (~280–300 MB).

---

## 7. Preguntas concretas para Opus

**A. Estrategia offline**
1. ¿Cuál es la mejor jugada para que el offline "se sienta IA" **sin alucinar** datos de seguridad ni de pesca? Evaluá
   por lo menos estas, y elegí una:
   - a) Prender el retrieval BM25 (sin embeddings) y mejorar cómo se **presenta** la ficha (plantillas, recortes, contexto de la conversación).
   - b) Un LLM pequeño **sin fine-tuning** (p. ej. clase 0,5–1,5 B: Qwen2.5, Gemma 3 1B, SmolLM…) usado **solo para reescribir/componer**
     la ficha recuperada (RAG con respuesta fundada en la ficha), con verificación de que no agregó hechos.
   - c) Generar offline en el servidor (con Groq, mientras hay señal) **paráfrasis y variantes** de cada ficha y empaquetarlas
     como contenido OTA, para que el offline tenga mucha más variedad natural sin modelo local.
   - d) Algo que no estamos viendo.
2. ¿Cuál es el **diseño de "escalera de degradación"** ideal? Hoy es: acción directa → nube → reglas → frase de error. ¿Qué
   debería haber entre "nube" y "sin nada" (p. ej. caché de respuestas online recientes, respuestas pre-generadas, modelo local)?
3. ¿Cómo hacemos que la **transición online ↔ offline sea invisible** (mismo tono, misma memoria, mismo historial)?
4. ¿Cómo evitamos que un modelo local generativo se cuele en los temas reservados (emergencia, VHF, primeros auxilios, pagos)?

**B. Confiabilidad de la parte online**
5. ¿Cómo detectamos "internet útil" y "proxy sano" (health check, circuit breaker, timeout adaptativo) en vez de esperar 12 s?
6. Con Supabase Free casi sin cuota: ¿conviene seguir pasando por `ia-proxy`, o hay una alternativa gratuita y segura
   (sin exponer claves en el cliente) para la parte online?
7. ¿Streaming de respuestas? ¿Cuál es la forma más barata de implementarlo con este stack?

**C. Experiencia y calidad**
8. ¿Cómo reemplazamos 4500 líneas de reglas por algo más mantenible **sin perder** lo determinista de seguridad? ¿Qué se
   puede migrar a datos (JSON/fichas) y qué debe quedar como código?
9. ¿Cómo manejamos la **voz** (transcripciones con errores, mezcla de temas, ruido de río)?
10. ¿Cómo medimos "suena a IA de verdad"? Proponé un **conjunto de evaluación** (tamaño, categorías, métricas: acierto,
    alucinación, naturalidad, latencia, RAM, batería) que podamos construir con lo que ya tenemos (80 + 44 preguntas, 383 fichas).

**D. Entrega y operación**
11. Si proponés un modelo local: ¿cómo se distribuye con Supabase Free (50 MB por archivo, ancho de banda limitado) y con
    qué política de versiones, hash y reversa? ¿Y en **web**, donde no corre llama.cpp?
12. ¿Cómo hacemos para que el bucle de aprendizaje (`|||APRENDO|||` → admin → OTA) siga funcionando y no se contamine con respuestas malas?

---

## 8. Límites del trabajo (para que el plan sea realista)

- Una persona, sin presupuesto, **sin tiempo para reescribir todo**. Preferimos **cambios incrementales con marcha atrás**
  (flags en `SharedPreferences`/remotos) antes que reemplazos totales.
- El repo está en la rama `fase-0-contencion`, con cientos de cambios sin commitear y **trabajo de seguridad en curso**:
  evitá planes que dependan de refactors masivos de la base de datos.
- Hay **tests existentes** sobre el motor; el plan tiene que decir cómo no romperlos o cuáles actualizar.
- Las claves de proveedores **no pueden volver al cliente** (decisión de seguridad ya tomada).
- Idioma de las respuestas: español rioplatense, tono campechano, máx. ~3 líneas, sin markdown, sin emoticones.

---

## 9. Formato de respuesta que preferimos

1. **Diagnóstico** (máx. una página): qué confirmás, qué corregís de lo que dijimos, qué hipótesis descartás.
2. **Recomendación principal** en 5–8 líneas y **una alternativa** descartada con el motivo.
3. **Plan por fases** en tabla: Fase · Qué se hace · Archivos · Cómo se prueba · Puerta de salida (métrica y umbral) · Cómo se revierte · Esfuerzo.
   La **Fase 1 debe poder hacerse en pocos días** y dar una mejora que se note.
4. **Conjunto de evaluación** propuesto y cómo construirlo.
5. **Riesgos y qué haría falta medir antes** (RAM, latencia, batería en equipos reales).
6. **Preguntas abiertas** para nosotros.

Gracias. Si algo de lo descrito no coincide con el código, **confiá en el código** y avisanos.

---

### Apéndice — mapa de archivos para ubicarte rápido

| Tema | Ruta |
|---|---|
| Router de niveles | `lib/services/baqueano_ia_service.dart` |
| Estado del router / badge | `lib/services/ia_router_state.dart`, `lib/widgets/ia_status_badge.dart` |
| Motor offline (reglas) | `lib/services/el_guia_engine.dart` (+ `el_guia_app_engine.dart`, `el_guia_humor_engine.dart`, `el_guia_context.dart`) |
| Retrieval (BM25 / semántico) | `lib/services/guia_retrieval/*` |
| Cliente de IA online | `lib/services/groq_service.dart`, `ia_edge_function_client.dart`, `lib/config/groq_config.dart` |
| Proxy en la nube | `supabase/functions/ia-proxy/index.ts` |
| Prompts y conocimiento | `lib/services/capacitacion_service.dart`, `assets/elguia/personalidad.json`, `assets/elguia/capacitacion/base_conocimiento.json` |
| Librerías de respuestas | `assets/elguia/librerias/*.json` (222), `assets/elguia/app/*.json` (18) |
| Memoria del usuario | `lib/services/guia_memoria_service.dart` |
| Aprendizaje y sincronización | `lib/services/gemini_learner.dart`, `guia_knowledge_sync_service.dart`, `guia_ota_sync.dart`, `guia_local_updater.dart` |
| Copiloto (acciones en pantalla) | `lib/services/guia_copilot_brain.dart`, `copilot_action_service.dart` |
| UI del ayudante | `lib/widgets/guia_overlay.dart`, `lib/screens/chat_unificado_screen.dart`, `chat_asistido_screen.dart`, `lib/modulos/pescadores/guia_chat_screen.dart` |
| Voz | `lib/services/voice_service.dart`, `voz_service.dart` |
| Experimento de modelo chico | `mini_model_lab/` (`FASES.md`, `INFORME_RETRIEVAL.md`, `PASO1_RETRIEVAL.md`, `retrieval/`) |
| Tests | `test/el_guia_engine_*_test.dart`, `test/guia_retrieval_test.dart` |
