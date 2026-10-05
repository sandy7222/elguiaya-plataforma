# Plan final — Ayudante IA "El Guía"

> Versión 1 · 2 de octubre de 2026. Responde a `docs/CONSULTA_OPUS_AYUDANTE_IA.md` e incorpora las respuestas del dueño.
> Regla general: cada paso es chico, tiene un test o una medición que lo aprueba y se puede revertir solo
> (flag en `SharedPreferences` o `git revert`). Ningún paso requiere pagar nada.

## Pendientes del dueño antes de arrancar

1. **Confirmar la Fase 0** (en el mensaje figura `[CONFIRMAR]`). El plan supone "sí, primero".
2. **RAM del Moto G15** (Ajustes → Acerca del teléfono). El plan **no depende** de ese dato, porque no hay
   modelo local. Sirve para registrar la latencia medida en el equipo de referencia.

## Decisiones tomadas

| Tema | Decisión |
|---|---|
| Estrategia offline | BM25 prendido + presentador determinista de fichas + paráfrasis generadas en el servidor. **Sin LLM local.** |
| Groq con señal | (a) Si hay ficha, se apoya solo en ella. (b) Si no hay ficha, puede hablar de pesca en general **sin datos duros** (medidas, vedas, leyes, números, horarios) y avisando que es orientación general. (c) **Nunca** responde temas reservados. |
| "No tengo ese dato" offline | Aceptado: 6 frases al azar, tono Baqueano, sin emojis, ≤ 3 líneas, con una salida (reformular, esperar señal, consultar a un capitán). En seguridad **siempre** se suman el 106 y el canal 16 de VHF. |
| Paráfrasis | Aprobación semiautomática con verificador. Al dueño solo le llegan las dudosas. Arranca en "modo sombra" (ver Fase 3). |
| Registro de preguntas | Solo anónimo: texto de la pregunta, sin nombre, correo, teléfono ni ID. Antes del lanzamiento: aviso y opción de no participar. |
| Cuota de Supabase | Nada agotado. Si alguna vez devuelve 402, la IA online cae al offline (el breaker de la Fase 1 lo hace rápido). |
| Equipo de referencia | Moto G15. |

## Qué hace hoy `GuiaLogger` (revisado)

- Guarda **solo en el celular**, en tres archivos dentro de la carpeta de documentos de la app:
  - `guia_preguntas.csv`: fecha y hora, intención, texto, si fue fallback.
  - `guia_retrieval.csv`: fecha y hora, decisión, puntajes, top 3, texto.
  - `guia_fallos_offline.json`
- **No guarda ID de usuario ni lo sube a ningún lado** (nada en `lib/` lo lee para enviarlo).
- Riesgo: el **texto crudo** puede traer datos personales que escribió el usuario ("soy Juan, mi cel es…"),
  y la fecha y hora exacta ayuda a reidentificar.
- Detalle de rendimiento: cada registro relee el archivo entero para rotarlo (hasta 5000 líneas por pregunta).

---

## Fase 0 — Seguridad (sin flag a propósito) · ~1 día

Objetivo: emergencia, primeros auxilios, VHF/Prefectura, "estoy perdido", GPS y pagos **nunca** llegan a Groq,
ni a filtros de humor, ni a retrasos.

| Paso | Qué se hace | Archivos | Puerta de salida |
|---|---|---|---|
| 0.1 | **Tests primero (en rojo).** `test/router_seguridad_test.dart` con unas 60 frases: directas ("me hundo"), indirectas ("se dio vuelta el bote", "no veo la costa"), con urgencia ("dale rápido que se hunde la lancha"), con errores de voz ("prefetura", "se me ase agua"), primeros auxilios, VHF, pagos. Simulación de "online" con un Groq falso que **falla el test si lo llaman**. Requiere una costura mínima en `BaqueanoIAService`: un `@visibleForTesting` para reemplazar la llamada a Groq y saltear la carga del catálogo de Supabase. | `test/router_seguridad_test.dart`, `baqueano_ia_service.dart` | Los tests corren y **fallan** contra el código actual (prueban la falla) |
| 0.2 | **Portón de seguridad** al principio de `responder()`, antes de diagnóstico, enojo, tristeza y temas prohibidos. Si la intención es de **seguridad**, responde el motor de reglas, sin nube y sin retraso. Si es **transaccional**, sigue a acción directa y tienda como hoy, pero se **saltea Groq**. Las sociales (saludo, mate, chiste) no cambian. **Modo emergencia pegajoso:** después de una emergencia, los 3 turnos siguientes ("¿y ahora qué hago?") también van a reglas. | `baqueano_ia_service.dart`, `el_guia_engine.dart` (hacer pública la consulta de intención reservada, dividida en seguridad, transaccional y social) | Las 60 frases: **0 llamadas a Groq** y **100 % responde el motor de reglas** |
| 0.3 | Sacar `dale`, `rapido`/`rápido` y `pura` del filtro de impaciencia (quedan las frases largas tipo "hace rato espero"). | `baqueano_ia_service.dart` | "dale rápido que se hunde la lancha" → respuesta de emergencia |
| 0.4 | Toda respuesta de seguridad, incluido el fallback de reglas en esos temas y los turnos del modo pegajoso, **contiene el 106 y el canal 16** (y en primeros auxilios, también 107/911). Ninguna respuesta de seguridad puede ser "no lo tengo claro" ni pedir más datos sin dar antes los contactos. **Preguntas reales del dueño como test de oro** (clasificación + contenido): "estoy en la isla perdido, cómo consigo agua?", "cómo hago fuego?", "me picó una raya en la pierna qué hago?", "me mordió una yarará o una víbora qué hago?", "estoy perdido cómo llamo a prefectura?", "me corté la piel, cómo paro el sangrado?", "tengo una fractura, qué hago?", "cómo llamo a prefectura?", "cómo pido auxilio?", "estoy perdido qué hago?", "se me clavó un anzuelo qué hago?" (y con error: "se me clavo una anzuelo"; hoy cada versión da una respuesta distinta), "algo me picó porque se hincha" (hoy: "No tengo esa información"; tiene que dar primeros auxilios y los signos de alarma de alergia grave → 107/911), "estoy perdido en la isla, qué puedo hacer para comer?". **Corregir contenido:** raya (hoy solo dice "presioná la herida"; falta lo central: agua caliente y atención médica), fractura (hoy no se reconoce: "Eso no lo tengo claro"), "estoy perdido qué hago" (sin pasos concretos ni contactos). Los textos de primeros auxilios los revisa una persona idónea (médico, guardavidas, Cruz Roja) antes del lanzamiento. | `el_guia_engine.dart`, `assets/elguia/librerias/primeros_auxilios.json`, `emergencia.json`, `router_seguridad_test.dart` | Las 10 preguntas reales: clasificadas como seguridad (salvo "cómo hago fuego?" suelta), con 106 y canal 16, y con el contenido mínimo de cada caso |
| 0.5 | El learner no aprende de temas reservados. Hoy `_intencionesProtegidas` depende del título que **inventa Groq** y le faltan primeros auxilios, Prefectura, VHF y pagos. Se agrega el chequeo con la intención **detectada por el router**. | `gemini_learner.dart`, `baqueano_ia_service.dart` | Test: pregunta reservada → `evaluarYGuardar` no envía nada |
| 0.6 | **El portón también en el overlay.** `guia_overlay.dart` (~línea 869) llama a `IntentService.detectarNavegacion` **antes** que al router, y navega sin preguntar. Hoy "podés ayudarme, perdí el ancla y me arrastra la corriente" podría terminar en la tienda. El chequeo de seguridad del 0.2 (misma función, no una copia) corre antes de `detectarNavegacion`, y también antes de los atajos de despedida. Revisar `chat_screen_simple.dart`, que también importa `IntentService`. | `guia_overlay.dart`, `chat_screen_simple.dart`, test en `router_seguridad_test.dart` (o uno nuevo sobre la función compartida) | Las 60 frases de seguridad, con productos y categorías cargados en el caché: **0 navegaciones** y 100 % de respuesta del motor de reglas |

**Reversa:** `git revert` del commit. No lleva flag a propósito.
**Tests existentes:** tienen que seguir verdes los 27 que pasan hoy. El que falla se arregla en 1.1.

---

## Fase 1 — Mejora visible, en pasos chicos · ~4–5 días en total

Cada paso es un commit propio y se prueba por separado.

| Paso | Qué se hace | Flag (`SharedPreferences`) | Archivos | Puerta de salida | Esfuerzo |
|---|---|---|---|---|---|
| **1.0** | **Navegación solo con pedido explícito.** Hoy `IntentService.detectarNavegacion` navega con casi cualquier frase: (1) basta **una** coincidencia de producto y compara pedazos de palabra ("pescar" contiene "pesca" → "Caja de Pesca"); (2) cuenta como orden `podés`/`podes` y cualquier texto que contenga `ver` ("verano", "river", "llover"); (3) `anzuelo` y `carnada` abren la tienda directo. Cambios: verbos explícitos con palabra entera ("llevame a", "abrí", "mostrame", "quiero comprar", "ir a la tienda"); las **preguntas** (cómo, qué, cuál, cuándo, dónde, por qué, "¿") **nunca navegan**; productos y categorías con **palabra entera** y ≥ 2 palabras significativas o el nombre exacto. Si el tema roza la tienda, **primero responde y después ofrece** ("…si querés, te muestro las cajas de pesca"), con un botón que el usuario toca o un "sí" por voz. Nunca navega solo. | `guia_nav_estricta` | `lib/services/intent_service.dart`, `guia_overlay.dart` (botón de oferta), nuevo `test/intent_service_test.dart` | Test con ~40 preguntas de pesca que hoy navegan ("qué carnada uso", "cómo pescar en verano", "podés decirme cómo se pesca el dorado"): **0 navegaciones**. Con ~20 pedidos explícitos ("llevame a la tienda", "mostrame las cañas"): **100 % navega bien** | 1 día |
| **1.0b** | **Lector de condiciones determinista** (hora, luna, clima), como el lector de productos del Tier 0: lee datos, **no los redacta una IA**. Corre en el router antes de la nube y, junto con 1.0, el overlay deja de navegar a `/clima` cuando el usuario **pregunta** (solo navega con "abrí el pronóstico"). **Hora:** reloj del celular. **Luna y solunar:** `SolunarService` (cálculo propio de la app, sobre `apsl_sun_calc`), sin internet. **Clima:** hoy `WeatherService.fetchMarineWeather` **no guarda nada**; se agrega un caché en `SharedPreferences` con la última respuesta completa (actual + 48 h por hora + 5 días), la hora de descarga, el lugar y la fuente. La pantalla de pronóstico, el `PronosticoMiniWidget` del panel del pescador y el Guía **escriben y leen el mismo caché**. Sin señal, el Guía usa el pronóstico guardado **para la hora actual** ("según el pronóstico que bajé a las 9:10, a esta hora tocaba 18 °C y viento de 12 km/h del sudeste"). Si el dato tiene más de 6 h, lo aclara; con más de 48 h dice que no tiene datos vigentes. **Seguridad:** nunca "ideal" ni "seguro para navegar"; si la pregunta es sobre salir o no, agrega "consultá el parte oficial del SMN o de Prefectura"; olas solo si `olajeDisponible`. Groq recibe estos mismos números como contexto (reemplaza la inyección por palabras clave de `capacitacion_service.dart`), para conversar sobre ellos sin recalcularlos. | `guia_condiciones` | nuevo `lib/services/guia_condiciones_service.dart`, `weather_service.dart` (caché), `baqueano_ia_service.dart` (Tier 0), `capacitacion_service.dart`, `intent_service.dart`, nuevo `test/guia_condiciones_test.dart` | Tests: hora correcta; fase lunar igual a la de `SolunarService` para 5 fechas fijas; con caché de 2 h → usa el pronóstico de la hora actual y dice la hora de descarga; con caché de 7 h → avisa que es viejo; sin caché → "no tengo datos"; **0 apariciones de "ideal" o "seguro"**. En el Moto G15 en modo avión: responde hora, luna y último clima en **< 300 ms** | 1–1,5 días |
| **1.1** | **Separar flags y prender BM25.** `guia_bm25` (por defecto **true**) prende el buscador léxico; `guia_semantico` (por defecto **false**) controla llama.cpp. Si alguien tenía `guia_retrieval_first=false` guardado a mano, se respeta como BM25 apagado. El test roto pasa a prender el flag de forma explícita. | `guia_bm25`, `guia_semantico` | `el_guia_engine.dart`, `test/el_guia_engine_retrieval_test.dart` | **4/4 archivos de test verdes.** En el Moto G15: el índice se arma en **< 2 s** sin trabar la primera respuesta (se mide con el `debugPrint` que ya existe) | ½ día |
| **1.2** | **Presentador de fichas.** Quita emojis, títulos en mayúsculas y numeración; arma 2–3 oraciones priorizando las que comparten palabras con la pregunta; ≤ 350 caracteres; agrega una entrada corta variada ("Mirá, chamigo…"). Nunca modifica números ni nombres: solo **recorta y une** oraciones de la ficha. | `guia_presentador` | nuevo `lib/services/guia_retrieval/guia_presentador.dart`, `el_guia_engine.dart` (`_respuestaDesdeFicha`), nuevo `test/guia_presentador_test.dart` | Sobre las 342 fichas: **100 % sin emojis ni markdown, ≤ 350 caracteres**, y **todo número de la salida existe en la ficha** | 1 día |
| **1.2b** | **Texto para voz, en un solo lugar.** Hoy `VoiceService.speak` limpia emojis y markdown, pero **borra los símbolos sin traducirlos**: "50 %" se lee "cincuenta", "18 °C" se lee "dieciocho ce", "12 km/h" se lee "doce kmh", "$15.000" se lee "pesos quince mil", "1." se lee "uno punto", y los títulos en MAYÚSCULAS algunos motores los deletrean. Además hay dos caminos de TTS sin ninguna limpieza (`audio_service.dart`, `voz_service.dart`). Se crea **una función** `prepararParaVoz(texto)` que usan todos: saca emojis, comillas (rectas y curvas), viñetas, numeración y markdown; traduce unidades (`%` → por ciento, `°C` → grados, `km/h` → kilómetros por hora, `$N` → N pesos, `cm`, `m`, `kg`, `gr`); pasa los títulos en mayúsculas a minúsculas, salvo siglas conocidas (VHF, GPS, SMN, PNA). Lo que se **muestra** en pantalla lo limpia el presentador (1.2); esto es solo para lo que se **dice**. Vale también para las respuestas de Groq. | `guia_voz_limpia` | nuevo `lib/services/guia_texto_voz.dart`, `voice_service.dart`, `audio_service.dart`, `voz_service.dart`, nuevo `test/guia_texto_voz_test.dart` | Test con ~40 textos reales (fichas crudas, respuestas de Groq con comillas y emojis, el clima del 1.0b): **0 emojis, comillas, asteriscos ni numeración** en la salida; cada unidad traducida; ningún número perdido | ½ día |
| **1.2c** | **Pronunciación.** El motor de voz pone el acento según la ortografía: si falta una tilde, lo pone mal ("rio" en vez de "río", "estas" en vez de "estás", "llama" en vez de "llamá"). Hay textos de respuesta sin tildes; por ejemplo, en `alimento.json`: "Si estas cerca del rio, la pesca es la fuente mas confiable". (1) **Script de tildes** sobre los campos de **respuesta** de `assets/elguia/` (no sobre los activadores, que van sin tilde a propósito): corrige solos los casos sin ambigüedad (río, surubí, patí, pacú, Paraná, yarará, también, después, día, tenés, podés) y lista para revisión a mano los ambiguos (estas/estás, mas/más, como/cómo, que/qué, llama/llamá). (2) **Léxico de pronunciación** editable por el dueño, `assets/elguia/voz/pronunciacion.json`, que `prepararParaVoz` aplica antes de hablar: nombres propios y guaraníes, palabras en inglés del equipo de pesca (spinning, baitcasting, jig, leader, kayak) y siglas (VHF → "ve hache efe"). (3) **Prueba de oído:** una pantalla oculta de admin que lee 50 frases de prueba con la voz del celular; el dueño marca las que suenan mal y se agregan al léxico. | `guia_pronunciacion` | script nuevo en `scripts/` (corre en la PC, no en la app), `assets/elguia/voz/pronunciacion.json`, `guia_texto_voz.dart`, test | Script: **0 casos sin ambigüedad** pendientes en respuestas; lista de ambiguos revisada. Prueba de oído en el Moto G15: **≥ 47/50** frases bien pronunciadas | 1 día + revisión del dueño |
| | ⚠️ Conviene **no repartir un APK** entre 1.1 y 1.2: sin el presentador, las fichas salen largas y con emojis. | | | | |
| **1.3** | **"No tengo ese dato" honesto.** 6 frases al azar cuando el buscador decide "ninguna" y las reglas caen en fallback. Si la pregunta roza seguridad, se suman el 106 y el canal 16. | `guia_no_se_honesto` | `el_guia_engine.dart` (o `assets/elguia/personalidad.json` para las frases) | 44 fuera de dominio: **0 respuestas inventadas** y ninguna frase repetida dos veces seguidas | ½ día |
| **1.4** | **Quitar el retraso artificial** de 400–1200 ms (la Fase 0 ya lo quita para seguridad). | `guia_retraso_artificial` (por defecto false) | `baqueano_ia_service.dart` | Offline p95 **< 300 ms** en el Moto G15 | ¼ día |
| **1.5** | **Proxy más rápido.** El cliente manda `reasoning_effort: "low"` y `max_completion_tokens` (~600, porque el razonamiento también cuenta tokens). El proxy acepta solo esos valores en una lista blanca. Antes hay que verificar con un pedido de prueba que Groq acepta los dos parámetros con `gpt-oss-120b` y que `finish_reason` no queda en `length`. | `guia_groq_rapido` (del lado del cliente) | `groq_service.dart`, `ia_edge_function_client.dart`, `supabase/functions/ia-proxy/index.ts` | 20 pedidos: **p50 menor que hoy** y **0 respuestas cortadas** | ½ día |
| **1.6** | **Circuit breaker + timeout de 6 s.** Si Groq falla o tarda, la nube queda "abierta" 60 s (después 5 min). Mientras tanto se va directo al offline. Si Supabase devuelve 402 o 429, el breaker se abre de inmediato. | `guia_breaker` | nuevo `lib/services/ia_breaker.dart`, `baqueano_ia_service.dart`, `groq_service.dart` | Con un proxy simulado caído: **primera respuesta ≤ 6 s; siguientes < 300 ms** | 1 día |
| 1.7 *(opcional)* | **Carrera nube contra offline**: si a los 3 s no respondió la nube, responde el offline. ⚠️ Hoy el motor offline **modifica el contexto** al responder (`_actualizarContexto`), así que antes hace falta un modo "sin efectos". Si se complica, pasa a la Fase 3. | `guia_carrera` | `el_guia_engine.dart`, `baqueano_ia_service.dart` | Ninguna respuesta duplicada; el contexto queda igual cuando gana la nube | 1 día |

**Reversa de la Fase 1:** apagar el flag correspondiente (o desplegar la versión anterior del proxy en 1.5).

---

## Fase 2 — Medir de verdad · ~1 semana (casi todo es escribir preguntas)

| Paso | Qué se hace | Puerta de salida |
|---|---|---|
| 2.1 | **Registro anónimo.** Antes de guardar, una limpieza borra correos, teléfonos, secuencias de 6 o más dígitos y lo que sigue a "me llamo" o "soy". Se guarda **solo el día** (no la hora). La rotación se hace cada 100 registros, no en cada uno. | Test con 20 textos con datos personales: **0 quedan** |
| 2.2 | **Subida anónima** de los usuarios de prueba: tabla nueva con permiso de **solo inserción** y **sin lectura** desde la app: `texto`, `decision`, `version_app`, `dia`, sin ID. Flag `guia_registro_anonimo`. Antes del lanzamiento: aviso y opción de no participar en el perfil. *Alternativa sin tocar la base:* botón "exportar" en el panel de admin y mandar el CSV a mano. | Una fila de prueba subida sin ningún dato del usuario (se verifica con SQL) |
| 2.3 | **Conjunto de evaluación** (~400 casos en `test/eval/*.jsonl`). Incluir las preguntas reales del dueño que no son de seguridad y hoy fallan: "cómo se arma una carpa?" (hoy la toma como el pez carpa y lista especies), "qué puedo hacer para comer?" (hoy: "No tengo esa información"). Contenido: 120 de pesca **reescritas a mano** (sin el nombre de la librería) + preguntas reales registradas; 64 fuera de dominio; 60 de seguridad (las de la Fase 0); 40 transaccionales; 40 conversaciones multiturno; 30 transcripciones de voz dictadas en el Moto G15; 20 de temas mezclados. | Archivos completos y revisados |
| 2.4 | **Runner** `test/eval_guia_test.dart` que corre el motor offline y escribe un informe JSON. Se **recalibran** los umbrales de BM25 (los de Python no sirven: otra escala). | Pesca: **≥ 85 % top-1** y **≤ 3 % de respuestas directas equivocadas**. Fuera de dominio: **≤ 5 % de falsos positivos**. Seguridad: **100 %** |

**Reversa:** solo agrega archivos; la subida se apaga con su flag.

---

## Fase 3 — Variedad y continuidad · ~1,5 semanas

| Paso | Qué se hace | Flag | Puerta de salida |
|---|---|---|---|
| 3.1 | **RAG online con la política (a)/(b)/(c).** El prompt incluye las 2 mejores fichas del buscador y la orden de no salirse de ellas. Sin ficha: orientación general, con un **verificador posterior** que busca datos duros (números con unidad, "veda", "ley", "decreto", horarios). Si encuentra alguno, se reemplaza por "no tengo ese dato". | `guia_rag_online` | 50 preguntas online: **0 datos duros fuera de una ficha** |
| 3.2 | **Caché de respuestas online:** se guardan las últimas ~200 respuestas de Groq por ficha o pregunta normalizada (nunca de temas reservados) y se reusan offline pasando por el presentador. | `guia_cache_online` | Offline repite una respuesta online buena para preguntas ya hechas |
| 3.3 | **Paráfrasis + verificador.** Un GitHub Action (gratis; la clave de Groq queda como secreto de GitHub) genera 3–5 variantes por ficha. El verificador exige que números, unidades, especies y nombres propios sean **idénticos** a los de la ficha, sin palabras prohibidas, sin emojis ni markdown, y con 80–350 caracteres. **Modo sombra 2 semanas:** todo llega al panel con el veredicto del verificador; el dueño revisa ~30. Si el verificador **no aprobó ninguna mala**, pasa a aprobación automática y al dueño solo le llegan las dudosas. Distribución por OTA (`GuiaOtaSync`, JSON de pocos KB). | `guia_parafrasis` | Verificador sin falsos aprobados en la muestra; la misma ficha pedida 5 veces da **≥ 3 textos distintos** |
| 3.4 | **Historial al offline:** el motor recibe los últimos turnos y resuelve seguimientos ("¿y con qué carnada?") con `objetivosRecientes`. | `guia_historial_offline` | Multiturno **≥ 75 %**; naturalidad offline **≥ 3,5/5** y brecha **≤ 1 punto** contra online (a ciegas, 50 casos) |

---

## Fase 4 — Voz y limpieza · incremental

### 4.M — Micrófono y palabra de activación

Problemas que hay hoy en `lib/services/voice_service.dart`:
- **Escucha a ráfagas**: 4 s escuchando y ~2 s sordo, cada 6 s (~línea 617).
- **Palabras de activación demasiado comunes**, buscadas como pedazo de texto (~línea 52): `guia`, `chamigo`,
  `una pregunta`. Saltan con "seguía" o con cualquier charla cercana.
- **Se puede escuchar a sí mismo**: mientras el Guía habla, cualquier palabra reconocida corta la respuesta (~línea 528),
  incluida su propia voz por el altavoz.

| Paso | Qué se hace | Flag | Puerta de salida | Esfuerzo |
|---|---|---|---|---|
| 4.M.1 | **Arreglos baratos sobre el código actual.** Frase de activación de dos palabras ("che Baqueano"), comparada por palabra entera. Mientras habla el TTS, ignorar lo escuchado salvo que el nivel de sonido (`onSoundLevelChange` de `speech_to_text`) supere claramente el de su propia voz. Exigir que la frase de activación se diga por encima del ruido de fondo medido. | `guia_mic_v2` | En el Moto G15, 10 minutos de charla de fondo / radio: **≤ 1 activación falsa**. 20 intentos de "che Baqueano" a ~50 cm: **≥ 18 aciertos**. El Guía no se interrumpe a sí mismo | 1–2 días |
| 4.M.2 | **Detector de voz (VAD) + nivel de fondo adaptativo.** Silero VAD (~2 MB, gratis, offline) con un nivel de ruido de fondo que se adapta. El reconocimiento de voz se prende **solo** cuando hay voz cerca por encima del fondo. Reemplaza las ráfagas. Antes: elegir y verificar un paquete Flutter que lo integre en Android (y ver qué pasa en web). | `guia_vad` | Grabaciones reales en el Moto G15 (motor, viento, agua, gente hablando): **≤ 1 activación falsa cada 10 min**. Batería: **≤ 5 % por hora** de escucha (a medir) | 3–5 días |
| 4.M.3 | **Palabra de activación propia "Baqueano"**, estilo Alexa, sobre el VAD. Opciones: **openWakeWord** (Apache 2.0; el modelo se entrena en Colab con voces sintéticas: es la excepción a "no volver a Colab") o **Picovoice Porcupine** (revisar si el plan gratis permite uso comercial). En Android 14+, escuchar en segundo plano exige un servicio en primer plano para el micrófono, con notificación visible. Se puede apagar desde "Ajustes de voz del Guía". | `guia_wake_word` | Mismas pruebas que 4.M.1 con pantalla apagada; batería medida en un día de pesca simulado | 1 semana |
| 4.M.4 | **Alternativas sin palabra de activación:** botón grande para hablar (ya existe) y, si se puede, el botón de auriculares Bluetooth. Con auriculares, el micrófono queda pegado a la boca. | — | Funciona con un par de auriculares Bluetooth comunes | ½–1 día |

- **Voz:** detectar la intención sobre **todas las alternativas** de `speech_to_text`. Si cualquiera dispara
  emergencia, gana. Puerta: 30 transcripciones con ruido, **100 %** en seguridad.
- **Reglas → datos:** usando `guia_retrieval.csv`, las reglas no críticas que el buscador ya resuelve se pasan a
  fichas y se borran del código, de a una por commit. Las de seguridad **quedan en código** con sus tests.
- **Código muerto:** borrar `asistente_chat_screen.dart` y `asistente_capitanya_screen.dart` (nadie las importa)
  y los comentarios que mencionan "Ollama".

## Fase 5 — Opcional, solo si las mediciones lo piden

- Streaming (fetch directo con SSE y TTS por oración).
- Proxy alternativo en Cloudflare Workers si Supabase llegara a cortar.
- Capa semántica (`guia_semantico`) solo si el eval muestra que BM25 falla con preguntas reales.

### 5.V — Voz (Gemini 3.8 Flash TTS), en este orden

Gemini TTS corre **solo en la nube**: no reemplaza a `flutter_tts` sin señal. Se usa de dos formas.

| Paso | Qué se hace | Flag | Puerta de salida |
|---|---|---|---|
| 5.V.0 *(ya, sin costo)* | Listar con `flutter_tts.getVoices()` las voces en español instaladas en el Moto G15 y elegir la más natural como voz offline por defecto. | — | El dueño elige la voz de oído |
| 5.V.1 | **Biblioteca de audios de frases fijas** (ver abajo). Funciona sin señal. | `guia_audios_fijos` | 100 % de las frases de la biblioteca suenan desde el archivo; si falta alguno, habla `flutter_tts` |
| 5.V.2 | **Voz por la nube** para respuestas online: `ia-proxy` suma el proveedor `gemini-tts` (clave solo en el servidor), salida `audio/mulaw` a 8 kHz (~8 KB/s) y timeout corto; si falla, habla `flutter_tts`. Antes: revisar en los términos si la capa gratis usa los datos para entrenar y medir la cuota real. | `guia_voz_nube` | Audio de una respuesta típica ≤ 100 KB; primer sonido en < 2 s con buena señal |

**Biblioteca de audios (5.V.1)**
- **Contenido (solo texto fijo, nunca fichas recortadas):** instrucciones de emergencia con el 106 y el canal 16,
  las 6 frases de "no tengo ese dato", saludos, despedidas y avisos de sin señal. Total estimado: 40–80 frases.
- **Generación:** un GitHub Action (gratis) lee `assets/elguia/voz/frases.json` (`id`, `texto`), llama a Gemini TTS
  con una sola voz elegida, convierte con `ffmpeg` a Opus mono de ~16 kbps (unos 2 KB/s, total < 2 MB) y escribe
  `manifest.json` con `id`, `hash del texto`, `voz`, `versión` y `hash del archivo`.
- **Regla de seguridad:** el audio de emergencia **va como asset dentro del APK**, no por OTA, para que exista
  aunque el celular nunca se haya conectado. El resto puede ir por OTA (`GuiaOtaSync`).
- **Coherencia:** si el `hash del texto` del manifest no coincide con el texto que va a mostrar la app, no se
  reproduce el audio y habla `flutter_tts`. Así un audio viejo nunca dice algo distinto de lo escrito.
- **Reproducción:** hace falta un paquete de audio (por ejemplo `just_audio`; hoy solo están `flutter_tts` y
  `speech_to_text`). En web, las mismas frases se sirven como archivos estáticos.
- **Archivos:** nuevo `lib/services/guia_audios_fijos.dart`, `assets/elguia/voz/`, `.github/workflows/voz.yml`.

## Notas para quien implemente

- **Orden estricto:** Fase 0 completa antes de la 1. Dentro de cada fase, un paso = un commit, con los tests corridos:
  `flutter test test/guia_retrieval_test.dart test/el_guia_engine_retrieval_test.dart test/el_guia_engine_pna_test.dart test/el_guia_engine_v2_test.dart`.
  Línea base al 2-oct-2026: pasan 27 y falla 1 (`el_guia_engine_retrieval_test.dart`, "devuelve la ficha tal cual",
  porque el flag está apagado y el test no lo prende).
- **Dónde está cada cosa:**
  - Router: `BaqueanoIAService.responder` en `lib/services/baqueano_ia_service.dart` (~línea 239).
  - Llamada a Groq: ~línea 360.
  - Retraso artificial: ~línea 400.
  - Filtro de impaciencia: ~línea 766.
  - Intenciones reservadas: `_intencionesReservadas` y `_esIntencionReservada` en `el_guia_engine.dart` (~líneas 99 y 1554).
  - Flag del buscador: línea 76; se lee de `SharedPreferences` en ~1344.
- **Costura para tests (0.1):** `responder()` llama a `_asegurarInicializado()`, que carga el catálogo desde Supabase
  (no está inicializado en tests), y crea `GroqService()` directamente. Hacen falta ganchos `@visibleForTesting`
  para reemplazar la llamada a Groq y saltear la carga del catálogo. No meter inyección de dependencias en todo el servicio.
- **`weather_service.dart` tiene un cambio sin commitear que es una corrección de seguridad:** antes, si Open-Meteo
  fallaba, inventaba datos (olas de 0,3 m por defecto, pronóstico de 5 días armado, "IDEAL PARA PESCA"). Ahora
  devuelve "no disponible". **Se commitea tal cual y no se revierte.** El caché de 1.0b se construye encima.
- **Ubicación sin señal:** `LocationPreferenceService.getPredefinedLocation()` usa la ubicación guardada. Si no hay
  ninguna, intenta GPS y geolocalización por IP antes de caer en San Fernando. Para 1.0b, sin señal usar el lugar
  **guardado en el caché del clima**, no volver a intentar la cascada.
- **Hay dos puertas de entrada al ayudante:** el router (`BaqueanoIAService.responder`) y el overlay
  (`guia_overlay.dart`), que antes del router corre despedidas y `IntentService.detectarNavegacion`. Todo control de
  seguridad tiene que cubrir **las dos** (paso 0.6).
- **No mezclar listas:** las reservadas de **seguridad** cortan todo; las **transaccionales** solo saltean Groq
  (las acciones en pantalla deben seguir andando); las **sociales** no cambian en el router.
- **`_cacheRespuestas`** hoy nunca se escribe. No asumir que funciona; se implementa en 3.2.
- **El motor offline modifica el contexto al responder.** Tenerlo en cuenta en 1.7 y en cualquier cosa que lo llame "para ver".
- **Los cambios de `ia-proxy` se despliegan aparte** (Supabase). Guardar la versión anterior para poder volver.
- Si algo del código no coincide con este plan, **manda el código**: anotar la diferencia acá y seguir.

## Qué no hacer

- No volver a hacer fine-tuning de un modelo chico ni poner un LLM local "para redactar".
- No mostrar fichas crudas sin el presentador.
- No dejar que la nube, el humor o el buscador toquen temas de seguridad.
- No calibrar umbrales con preguntas de plantilla.
- No usar el registro de preguntas con datos identificables.
