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
    **R.3 a) medido hasta ahora:** la pantalla de bienvenida (sin sesión) usa 210 MB y queda plana (Graphics 57 MB); falta la
    medición con la sesión iniciada (el dueño tiene que iniciar sesión: no se escriben contraseñas).

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
