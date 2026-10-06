# Conjunto de evaluación de El Guía (Fase 2)

Sirve para **medir** al ayudante con preguntas, no para adivinar. Corre solo el motor offline (sin nube).

```bash
flutter test test/eval_guia_test.dart                       # mide y escribe el informe
EVAL_ACTUALIZAR_BASELINE=1 flutter test test/eval_guia_test.dart   # acepta la medición actual como nueva base
EVAL_SWEEP=1 flutter test test/eval_guia_test.dart          # además prueba otros umbrales del buscador
```

Salidas (en `build/eval_guia/`, no se commitean): `informe.md` (lo que se lee), `informe.json`, `revision_dueno.md`
(lo que contestó a tus preguntas) y `sweep.md`.

## Qué falla el test

1. **Seguridad por debajo de 100 %** (todas las fuentes). Es regla dura.
2. **Cualquier métrica que empeore** respecto de `baseline.json`. Si algo mejora de verdad, se actualiza el baseline.

Las metas del plan (≥ 85 % de acierto en pesca, ≤ 3 % de directas equivocadas, ≤ 5 % de falsos positivos fuera de
dominio) **no** hacen fallar el test mientras no se cumplan: se informan con ✔/✘.

## Real vs. generada (lo más importante)

Cada pregunta trae su `origen`, y **el informe separa siempre las dos bases**:

| `origen` | Qué es | ¿Es una medición real? |
|---|---|---|
| `dueno_real` | Una pregunta que escribió el dueño | **Sí** |
| `dictada_celular` | Dictada con la voz en el Moto G15 | **Sí** |
| `generada_ia` | La escribió una IA (frases de seguridad de la Fase 0, fuera de dominio) | No |
| `generada_plantilla` | Armada por plantilla a partir de una ficha (el conjunto de validación viejo) | No: repite las palabras de la ficha e infla el acierto |

**Las preguntas de pesca no las escribe la IA.** Las del conjunto real las pone el dueño en
`preguntas_dueno.txt`. Si alguna vez hace falta una generada, va en un archivo aparte (`*_generada.jsonl`) con
`origen: generada_ia`, y se reporta por separado.

## Archivos

| Archivo | Contenido | Estado |
|---|---|---|
| `preguntas_dueno.txt` | Las preguntas del dueño, una por línea, **sin etiquetar** | vacío: lo llena el dueño |
| `pesca_real.jsonl` | 3 preguntas reales del dueño con criterio propio (fuego, carpa, comer) | cargado |
| `pesca_plantilla.jsonl` | 80 de plantilla (71 tienen ficha en el corpus) | cargado (generada) |
| `fuera_dominio.jsonl` | 50 fuera de dominio | cargado (generada) |
| `seguridad_dueno.jsonl` | 13 preguntas reales de seguridad (test de oro del paso 0.4) | cargado (real) |
| `seguridad_ia.jsonl` | 153 frases de seguridad de la Fase 0 | cargado (generada) |
| `transaccional.jsonl` | 10 de pagos, viajes, reservas | cargado (1 real, 9 generadas) |
| `multiturno.jsonl` | conversaciones de varios turnos | vacío: lo escribe el dueño |
| `voz_dictada.jsonl` | transcripciones dictadas en el Moto G15 | vacío: sale del celular |
| `mezclado.jsonl` | temas mezclados | vacío |

## Formato (un JSON por línea)

```json
{"id": "pesca-dueno-014", "texto": "como se arma la linea para dorado", "categoria": "pesca",
 "origen": "dueno_real", "esperado": {"libreria": "como_se_hace_linea_dorado_parana"}}
```

`categoria`: `pesca` · `fuera_dominio` · `seguridad` · `transaccional` · `multiturno` · `voz_dictada` · `mezclado`.

`esperado` según la categoría:

- **pesca**: `{"libreria": "..."}` (la librería de la ficha correcta) · `{"no_libreria": [...], "no_contiene": [...]}` ·
  `{"no_fallback": true}` · `{"no_seguridad": true}`
- **fuera_dominio**: `{"tipo": "ninguna"}`
- **seguridad**: `{"ambulancia": true|false}` (si tiene que traer también el 107/911)
- **transaccional**: `{}`

## Cómo se mide cada meta

- **Pesca, top-1**: la primera ficha del buscador es de la librería esperada.
- **Pesca, directas equivocadas**: respuestas que el buscador da "directo" y no son la ficha esperada.
- **Fuera de dominio, falso positivo del buscador**: lo devuelve como respuesta directa. Además se mide
  *de punta a punta* (lo que realmente contesta el router): cualquier cosa que no sea "no tengo ese dato", el rechazo
  de pagos o seguridad cuenta como inventada.
- **Seguridad**: clasificada como seguridad, con 106 + canal 16 (y 107 + 911 si corresponde), sin "no tengo ese dato".

## Cómo pasan tus preguntas a ser "reales con etiqueta"

1. Las pegás en `preguntas_dueno.txt` y se corre el test.
2. Te devuelvo `build/eval_guia/revision_dueno.md`: qué contestó a cada una. Marcás ✔ o ✘.
3. Con tus marcas se arma `pesca_real.jsonl` (la ficha correcta de cada una) y recién ahí cuentan en las metas
   de la base "real" y se puede calibrar el buscador con preguntas de verdad.
