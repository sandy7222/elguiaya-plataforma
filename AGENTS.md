# AGENTS.md — Léeme primero

> Instrucciones para **cualquier asistente de IA** que trabaje en este repositorio (Claude, Cursor, Copilot,
> Codex, ChatGPT, Gemini/Antigravity, Qwen u otro). `CLAUDE.md`, `GEMINI.md`, `QWEN.md` y
> `.github/copilot-instructions.md` solo apuntan acá: **este es el único archivo que se mantiene**.
>
> **Antes de hacer nada:** leé este archivo completo y después `docs/ESTADO.md` (dónde quedó el trabajo).
> **Al terminar cada paso:** actualizá `docs/ESTADO.md` (ver "Cómo se trabaja").

## 1. Qué es esto

- **El Guía YA / Capitán YA:** app **Flutter** (Android + web) para pescadores argentinos del Paraná, islas y costa.
  Tiene tres partes: un marketplace de **viajes de pesca** (el pescador contrata a un capitán), una **tienda**
  de artículos de pesca y **"El Guía"**, un ayudante con IA que tiene que funcionar **también sin señal**.
- **Dueño:** una sola persona, monotributista, **sin presupuesto**. No programa: trabaja con asistentes de IA.
  Todo lo que se proponga tiene que ser gratis o casi gratis, y mantenible por una persona.
- **Idioma:** español rioplatense, en la app y al hablar con el dueño. Explicarle en lenguaje simple, sin jerga.
- **Usuarios:** hoy **todos son de prueba**. Nadie externo usa la app todavía.
- **Backend:** Supabase, plan Free (proyecto `CapitanYA-MASTER`). Web en Vercel (sirve el bundle de `public/`).
- **Rama de trabajo:** `fase-0-contencion`. **No** trabajar sobre `main`.

## 2. Reglas que no se negocian

1. **Seguridad del ayudante:** emergencias, primeros auxilios, "estoy perdido", VHF/Prefectura, GPS y todo lo de
   **dinero o transacciones** los responde **siempre el motor de reglas determinista**, nunca un modelo
   generativo (ni la nube ni uno local). Ante la duda, **gana seguridad**: es preferible una falsa alarma a no
   reconocer una emergencia. Toda respuesta de seguridad incluye el **106** (Prefectura) y el **canal 16 VHF**;
   en primeros auxilios, también **107/911**. Lo controlan `test/router_seguridad_test.dart`,
   `test/guia_atajos_test.dart` y `test/frases_seguridad.dart`: **no se debilitan esos tests para que pase el código**.
2. **Nunca inventar datos:** ni clima, ni medidas, ni vedas, ni teléfonos. Si no hay dato, se dice "no tengo ese dato".
3. **Las claves de proveedores (Groq, Gemini, Mercado Pago) nunca van al cliente** (código Flutter). Viven solo como
   secretos del servidor (Edge Functions de Supabase). **No escribir secretos** en el código, en estos documentos
   ni en el chat.
4. **Nada irreversible sin un OK explícito del dueño:** `git push`, aplicar migraciones en la base de producción,
   desplegar Edge Functions, borrar datos o archivos, cambiar secretos o el modo de Mercado Pago.
5. **Pagos reales:** Mercado Pago está configurado en **modo producción**. Comprar desde la app **cobra plata real**.
   No hacer compras de prueba sin pasar antes a modo prueba (sandbox), con el OK del dueño.
6. **Textos médicos o de supervivencia:** no escribir protocolos nuevos por cuenta propia. Mejorar solo lo indicado
   en el plan y marcar cada texto tocado con `// REVISAR: persona idónea` (los revisa un médico o guardavidas
   antes del lanzamiento).
7. **Hay cientos de cambios sin commitear** del trabajo anterior. **No** commitear todo junto ni descartarlos:
   commitear solo lo que tocó cada paso. Si un archivo trae cambios ajenos, separarlos o avisar.

## 3. Cómo se trabaja (el método que viene funcionando)

1. **Un paso del plan por vez, un commit por paso.** Mensaje en español: qué cambió y **por qué**.
2. **Tests primero, en rojo:** escribir el test que demuestra el problema, verlo fallar contra el código actual,
   y recién ahí arreglar. Si un test pasa "de entrada", desconfiar.
3. **Todo cambio de comportamiento se puede revertir:** flag en `SharedPreferences` (`guia_*`) o `git revert`.
4. **Correr los tests antes de cada commit** y reportar el resultado real (cuántos pasan y cuáles fallan).
   Si no se cumple una meta del plan, **decirlo**; no ajustar el test para que pase.
5. **Si el código no coincide con un documento, manda el código:** anotar la diferencia y seguir.
6. **Al terminar cada paso, actualizar `docs/ESTADO.md`:** último paso hecho (con commit), qué sigue,
   y los problemas o pendientes nuevos. Es lo que lee la próxima IA.
7. Si no podés ejecutar comandos (por ejemplo, un chat sin acceso al repo), decilo y pedile al dueño que los corra.

**Tests del ayudante:**
```bash
flutter test test/router_seguridad_test.dart test/guia_atajos_test.dart test/guia_retrieval_test.dart test/el_guia_engine_retrieval_test.dart test/el_guia_engine_pna_test.dart test/el_guia_engine_v2_test.dart
```
Suite completa: `flutter test`. Analizador: `flutter analyze`.

## 4. Mapa de documentos

| Tema | Leer |
|---|---|
| Estado actual y qué sigue | `docs/ESTADO.md` (**siempre primero**) |
| Ayudante "El Guía": plan por fases, metas y notas para quien implementa | `docs/PLAN_AYUDANTE_IA.md` |
| Por qué se eligió ese plan (diagnóstico) | `docs/CONSULTA_OPUS_AYUDANTE_IA.md` |
| Seguridad de Supabase (RLS, políticas, funciones) | `docs/PLAN_EJECUCION_SEGURIDAD_SONNET.md`, `docs/AUDITORIA_FASE_2_RLS.md`, `docs/TAREA3_INVENTARIO_PERFILES.md` |
| Historia y mapa general del código | `docs/AUDITORIA_FASE_1_BASELINE.md` |
| Experimento descartado de modelo propio | `mini_model_lab/FASES.md` (archivado) |

⚠️ La sección de IA de `README.md` está **desactualizada** (habla de `llama-3.3` y dos niveles). La fuente
correcta es `docs/PLAN_AYUDANTE_IA.md`.

## 5. Mapa rápido del código del ayudante

| Qué | Dónde |
|---|---|
| Router (quién responde cada pregunta) | `lib/services/baqueano_ia_service.dart` (`responder`) |
| Motor de reglas offline + clasificador de seguridad | `lib/services/el_guia_engine.dart` (`clasificarIntencion`) |
| Atajos del overlay (silenciar, despedida, navegación) | `lib/services/guia_atajos.dart`, `lib/widgets/guia_overlay.dart` |
| Buscador de fichas (BM25) y presentador | `lib/services/guia_retrieval/` |
| Navegación por voz o texto | `lib/services/intent_service.dart` |
| Nube (Groq vía proxy) | `lib/services/groq_service.dart`, `supabase/functions/ia-proxy/` |
| Voz | `lib/services/voice_service.dart` |
| Respuestas y conocimiento | `assets/elguia/` (librerías JSON, `personalidad.json`) |

**Hay dos puertas de entrada al ayudante:** el router y el overlay. Todo control de seguridad tiene que cubrir las dos.

## 6. Callejones sin salida (no repetir)

- **Entrenar un modelo chico propio** (Gemma 270M en Colab) para responder: fracasó en 4 corridas porque inventa
  datos. Archivado en `mini_model_lab/FASES.md`.
- **LLM generativo dentro del celular:** descartado (RAM, tamaño, no corre en web, inventa).
- **Claves de IA en el cliente:** se sacaron por seguridad; no vuelven.
- **Medir el buscador con las 80 preguntas de `dataset_validacion_v5.jsonl`:** son de plantilla, no reales; inflan
  el acierto. Usar las preguntas reales del dueño (están en los tests de oro del plan).
- **Detectar intenciones buscando pedazos de palabra** (`contains`): causó "pescar" → producto "Caja de Pesca",
  "el bot" → "el bote", "ver" → "verano". Comparar palabras enteras.
