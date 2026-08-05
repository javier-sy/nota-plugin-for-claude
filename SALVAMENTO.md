# Pase de salvamento de `src/rules/` — hoja de arbitraje

Trabajo de E1c (ver `PLAN-skills.md` §5.7). Recorrido de `musadsl-philosophy.md`
(7,8 KB) y `musadsl-reference.md` (35 KB) afirmación por afirmación, más el
triaje A/B/C de las 23 prácticas, contra los `docs/` de musa-dsl.

**Nada implementado.** Esto es la hoja que Javier arbitra.

Método: **contraste por significado, no por texto**. Donde una afirmación era
verificable, se ha ejecutado.

---

## 0. Lo que no esperábamos

El pase se planteó como *"mover prosa a su sitio"*. Encontró otra cosa.

### Cinco afirmaciones falsas, cuatro en el plugin y una en la gema

| # | dónde | afirmación | realidad |
|---|---|---|---|
| 1 | `philosophy.md:77` | *"Series constructors must be defined **outside** `sequencer.with` blocks — they are not available inside the DSL context"* | **Falsa.** `S(1,2,3)` dentro de `with` devuelve `[1,2,3]`. Verificado ejecutando. Y **`reference.md:804` ya la había retractado**: dos ficheros de `rules/`, ambos siempre en contexto, uno diciendo lo contrario del otro |
| 2 | `philosophy.md:85` + 5 sitios más | **`Rules`** como herramienta generativa de musa-dsl, con código ejecutable en `reference.md:412` | **Salió a la gema `musa-rules` en 0.47.** `lib/musa-dsl/generative/` tiene cuatro ficheros y ninguno es `rules`. **Los `docs/` de la gema se corrigieron: cero menciones.** El plugin la sigue enseñando en `philosophy.md`, `reference.md` (×3), `code/SKILL.md` (×3), `explain/SKILL.md`, `think/SKILL.md` |
| 3 | `philosophy.md:89` | *"A Markov chain produces a sequence of state values; those values become elements of a serie"* | **Markov ES una serie**: `markov.rb:120` incluye `Musa::Series::Serie::Base`. Puede alimentar `play` directamente |
| 4 | `best-practices/ctrl-c-thread-safe` | *"`transport.stop` uses a Mutex internally, so it cannot be called from a signal handler"* | **Imprecisa, no falsa** — ver la corrección abajo. La recomendación es **correcta y verificada**; lo que estaba mal era dónde se dice que está el mutex |
| 5 | **`musa-dsl/docs/subsystems/series.md:225`** | *"`RND(...)` - Random values (infinite)"* | **Falsa.** `RND(1..6)` da seis valores y `nil` al séptimo; `infinite?` → `false`. Es un *shuffle*, no un dado. Muestreo con reemplazo es `RND(...).repeat` |

El 2 es el más grave: cualquier usuario que le pida a Nota *"una estructura que
crece por reglas"* recibe código que lanza `NameError`.

### Corrección al hallazgo 4 (autocrítica del propio pase)

La primera lectura concluyó *"no hay Mutex en el camino"* porque `transport.rb` no
contiene ninguno: `Transport#stop` es `@clock.terminate`. **Esa conclusión era
demasiado fuerte, y sale de mirar un fichero en vez de ejecutar.** La prueba
directa —instalar el trap, mandarse la señal— da el camino completo:

```
Transport#stop → @clock.terminate → (callback) → Transport#do_stop  (transport.rb:511)
  → Sequencer#reset → BaseSequencer#reset                          (base-sequencer.rb:295)
  → TickBasedTiming#_reset_timing                       (base-sequencer-tick-based.rb:223)
  → Mutex#synchronize → ThreadError: can't be called from trap context
```

**El transport sigue corriendo**: `transport.start` nunca retorna. Así que la
práctica acierta en lo que importa y falla en la localización — el mutex no está
en `Transport#stop`, se alcanza tres marcos más abajo, en el *reset* de *timing*
del sequencer.

Es la misma lección del programa aplicada a sí mismo: **leer el fichero no es
verificar; ejecutar sí.** Y deja `ctrl-c-thread-safe` como práctica del **grupo A
con hecho verificado**, no en cuarentena. Su **solución también se comprobó**:
`Thread.new { transport.stop }` desde el trap funciona — `transport.start`
retorna limpiamente.

### Hallazgo 6, de releer las prácticas enteras

**`state-machine-composition.md` no compila.** Seis líneas suyas son errores de
sintaxis de Ruby:

```
línea 38  control.after { wait 1/8r { launch :exposition } }
línea 47  control.after { wait 1/8r { launch :development } }
línea 50  at 1 { launch :exposition }
líneas 66-68  at 1 { … }  at 17 { … }  at 33 { … }
```

Son exactamente el error que **la Critical Guard del propio plugin prohíbe**:
*"NEVER write `at 1 { ... }` — this is a Ruby syntax error because curly-brace
blocks bind to the last argument"*. Verificado con `ruby -c`. Una práctica que
enseña código que no parsea, contradiciendo la guarda que viaja en el mismo
contexto.

### Lo que la relectura confirmó como correcto

Para que no se re-audite: `.instance` existe de verdad (`base-series.rb:431`, con
`.i` como alias corto); `Transport.new` acepta `do_log:`; `DummyClock.new` acepta
bloque; `voices.panic` manda **CC 123** (`0x7b`) por canal; `do_stop` ejecuta los
`after_stop` **y luego** resetea el sequencer —así que el *"no llames a
`sequencer.reset`"* de `shutdown-pattern` es cierto, y además **ya está en
`transport.md:130-131`**—; y `NeumaDecoder#base=` existe.

El 5 invierte la expectativa del pase: **la transcripción es en este punto más
correcta que la fuente**. La razón es instructiva — los *pitfalls* de
`reference.md` se reconstruyeron en esta sesión contra
`spec/reference_pitfalls_spec.rb` (13 ejemplos), así que **su ancla ya está en
musa-dsl aunque su prosa viva en el plugin**. Media reforma hecha: el anclaje
correcto, la residencia equivocada.

### La asimetría que lo explica

Los *pitfalls* recibieron el tratamiento de F2.5 —*"a warning with no spec behind
it is a conjecture with typography"*, y tres de sus avisos resultaron falsos—.
**Las 23 prácticas nunca lo recibieron.** Por eso el hallazgo 4 vive ahí y no
entre los pitfalls. Si las prácticas del grupo A migran a musa-dsl, migran a un
sitio donde esa disciplina existe; ése es medio argumento a favor de moverlas,
independiente del de propiedad.

---

## 1. `musadsl-philosophy.md` — veredicto

| § | afirmación | veredicto |
|---|---|---|
| Core principle | GDV / PDV / Transcription como tres capas; *"never collapse prematurely"* | **duplicado** — `idioms.md` #4 *"Layers: musical intent vs. realization"*, más `datasets.md` y `transcription.md` |
| Series | lazy / functional / composable / reusable + tabla de 10 idiomas | **duplicado** — `series.md` "When is this the answer" (tabla equivalente y mejor: por necesidad musical) e `idioms.md` #2 |
| Prototype/instance | `.i`, `.buffered` + `.buffer.i` | **duplicado** — `series.md` e `idioms.md` |
| Sequencer | primitivas `at`/`wait`/`every`/`play`/`move`; *"keep musical decisions out"* | **duplicado** — `sequencer.md`, y el principio raíz de `idioms.md` lo dice mejor (*"the shape of the data decides the idiom"*) |
| Sequencer | *"constructors not available inside the DSL context"* | **FALSO** (hallazgo 1) — muere, y hay que borrarlo también de donde se haya propagado |
| Generative | cinco herramientas descritas en lista plana | **duplicado y peor** — `generative.md` las organiza por pregunta musical, con la distinción que decide (*"can you say what you want, or only recognise it when you hear it?"*), el *"when it is NOT the answer"* y la regla de semilla. Y una de las cinco no existe (hallazgo 2) |
| Generative | *"su salida alimenta a Series"* | **FALSO/impreciso** (hallazgo 3) → **candidato a corrección en `generative.md`**: *Markov es él mismo una serie* |
| Neumas | GDV, duración múltiplo de `base_duration` | **duplicado** — `neumas.md:66,87-89`, con el matiz del compás mejor explicado |
| Events | `on`/`launch` macro; `after` natural vs `on_stop` cualquiera | **duplicado** — `sequencer.md` e `idioms.md` |
| Rational | nunca Float | **duplicado** — `sequencer.md:174`, `idioms.md` |

**Veredicto global: `musadsl-philosophy.md` muere entero.** Ocho de sus diez
afirmaciones están en la gema, dicha mejor; dos son falsas. **Salvamento neto: una
línea** — que Markov es una serie, y va a `generative.md` como corrección, no
como copia.

---

## 2. `musadsl-reference.md` — veredicto

### 2.1 El cuerpo de API (líneas 77-770, ~24 KB)

Listado puro de firmas por subsistema. **Sin avisos incrustados** — se buscaron:
cero líneas de comentario con `must`/`cannot`/`never`/`only`/`beware`.

**Muere entero**, sustituido por `docs/vocabulary.md` (§5.9 del plan) +
`api_reference` + `get_doc`. Excepción: la sección **Rules (409-432) muere sin
sustituto**, porque describe una gema distinta.

### 2.2 Los 12 *pitfalls* (771-799)

Cada uno anclado en `spec/reference_pitfalls_spec.rb`.

| # | pitfall | ¿está en los docs de musa-dsl? |
|---|---|---|
| 1 | `using` es *file-scoped* | **sí** — `neumas.md` → muere |
| 2 | series perezosas; **`.to_a` reinicia la instancia** | *lazy* sí; **`.to_a` reinicia, NO** → **candidato** (verificado: tras un `next_value`, `to_a` devuelve la serie entera) |
| 3 | duración múltiplo de `base_duration`, que es fracción de **compás** | **sí** — `neumas.md:66,87-89` → muere |
| 4 | Rational; **una posición Float se cuantiza al tick** (`at(1.3)` → `125/96r`) | el consejo sí (`sequencer.md:174`); **la cuantización concreta, no** → **candidato** (afila un aviso que hoy es genérico) |
| 5 | ornamentos silenciosos sin Transcriptor | **sí** — `transcription.md:19` → muere |
| 6 | `after` natural / `on_stop` cualquiera | **sí** — `idioms.md`, `sequencer.md` → muere |
| 7 | **canales MIDI 0–15, no 1–16** | **no** — `midi.md` los usa (`channels: [0, 1, 2]`) sin decir el rango → **candidato** (pequeño, pero quien viene de un DAW cuenta desde 1) |
| 8 | elemento sin `:duration` suena a la vez que el siguiente | **sí** — `datasets.md` → muere |
| 9 | **`RND()` es un shuffle que se agota** | **la gema dice lo contrario** → **corrección de `series.md:225`** (hallazgo 5) |
| 10 | `FIBO()` empieza en 1; las semillas son sus dos primeros valores | **sí** — `series.md:228`, correcto → muere |
| 11 | `move` toma `every:` como keyword | los ejemplos lo usan bien; el modo de fallo no se declara → **duplicado en efecto**, muere |
| 12 | nota sin duración suena hasta soltarla | **sí** — `midi.md:16,65-68` → muere |

**Ocho mueren, tres son candidatos, uno es un bug de la gema.**

### 2.3 "Removed from this list" (800-808)

Bitácora de correcciones. **No migra, pero no se tira sin más**: sus cuatro
entradas existen para que un aviso falso no se reintroduzca desde una copia
vieja. Al morir las copias, el registro pierde su función — salvo la entrada de
issue #73 (Rules) y la de #82, que son historia de musa-dsl y ya viven en sus
issues.

### 2.4 Demo Index (809+)

**Muere**: lo sirve `demo_readme` por semejanza. Su fila 08 documenta la demo de
*Voice Leading* con `Rules.new`, que hoy vive en `musa-rules/demo/voice-leading/`.

---

## 3. Las 23 prácticas — triaje A/B/C

Criterio: **¿la justificación cita una propiedad de musa-dsl o una preferencia
del compositor?**

### A — hechos del framework (destino: documentación de musa-dsl)

| práctica | el hecho | ¿ya en la gema? |
|---|---|---|
| `refinements-per-file` | `using` es file-scoped | **sí** → muere |
| `rational-timing` | Rational para todo tiempo | **sí** → muere |
| `seed-reproducibility` | sembrar todo lo estocástico | **sí** — `generative.md` *"Seed everything"* → muere |
| `series-parameterization` | parámetros como series desde el principio | **sí** — `series.md:19` (`S(value).repeat`) → muere |
| `buffered-series-for-parallel-voices` | `.buffered` + `.buffer` por voz | **sí** → muere |
| `play-h-pattern` | `H()` de series paralelas → `play` | **sí** → muere |
| `timer-clock-start` | `transport.start` bloquea | **sí** — `transport.md:61,144,188` → muere |
| `decoder-state-reset` | el decoder acumula valores relativos; hay que resetear entre secciones | **no** → **candidato, verificado** |
| `voice-accessor` (mitad hecho) | `MIDIVoices` no define `[]`; se accede por `.voices[n]` | **no lo declara** (`midi.md:56` usa `.voices.first`) → **candidato, verificado** |
| `ctrl-c-thread-safe` | `transport.stop` desde un trap lanza `ThreadError` y el transport no para | **no** → **candidato, verificado**, con la localización corregida |

### B — el oficio de componer con musa-dsl (destino: guía de convenciones, decisión 8)

`separation-main-score` · `module-thescore-pattern` · `methods-over-procs` ·
`shutdown-pattern` · `event-loop-pattern` · `state-machine-composition` ·
`clock-proxy-dual-mode` · `reactive-external-control` · `voice-accessor` (la
mitad del `v(n)`) · `debug-helper`

`separation-main-score` y `module-thescore-pattern` son el núcleo: responden *"¿cómo
estructuro una pieza?"*, que es la primera pregunta de cualquier recién llegado, y
sus justificaciones son propiedades del framework (main/score se separa **porque**
el transport bloquea y las voces son infraestructura).

`debug-helper` es el más débil de la lista: roza C.

### C — la voz del usuario (no migra)

`dual-level-logging` · `markov-blending` · `prime-period-automation` ·
`tick-aligned-durations`

`dual-level-logging` lleva dentro un hecho de A (que el sequencer genera salida
masiva en debug) que puede extraerse aparte.

---

## 4. Arbitraje de Javier — resuelto

Decidido el 5 de agosto de 2026.

1. **Banda media** → `clock-proxy-dual-mode`, `event-loop-pattern` y
   `debug-helper` son **oficio (B)**. Sólo `prime-period-automation` queda en
   **C**. El grupo B pasa a **diez prácticas**; el C se queda en cuatro:
   `dual-level-logging`, `markov-blending`, `prime-period-automation`,
   `tick-aligned-durations`.
2. **Las seis adiciones** → verificar las dos pendientes y redactar las seis.
   **Hecho: verificadas** (§5). Ninguna cae.
3. **`ctrl-c-thread-safe`** → re-verificar y reescribir. **Hecho**: la
   recomendación se confirma, la localización del mutex se corrige, y la práctica
   sube de cuarentena a **adición verificada** (§0, corrección al hallazgo 4).
4. **La guía de convenciones** → **`docs/guides/project-structure.md`**, en un
   directorio nuevo `docs/guides/` separado de `subsystems/` (referencia por
   capa) y de `idioms.md` (catálogo por síntoma):

```
docs/
├── subsystems/          ← referencia por capa (13)
├── guides/              ← NUEVO: oficio
│   └── project-structure.md
├── examples/
├── idioms.md            ← catálogo por síntoma
└── vocabulary.md        ← generado (PLAN-skills §5.9)
```

---

## 5. Correcciones y adiciones que salen para musa-dsl

**Un bug de documentación**, con su prueba:

- `series.md:225` — `RND(...)` no es infinita. Se agota tras una permutación;
  `infinite?` es `false`. Sustituto correcto en el pitfall 9, con spec.

**Siete adiciones, todas verificadas** (ninguna es una copia; todas son
conocimiento que hoy sólo existe dentro del plugin):

| # | destino | qué se añade | prueba |
|---|---|---|---|
| 1 | `series.md` | **`.to_a` reinicia la instancia** en vez de continuar desde donde dejó `next_value` | tras un `next_value` sobre `S(1,2,3).i`, `to_a` → `[1,2,3]` |
| 2 | `sequencer.md` | **una posición Float se cuantiza al tick**: `at(1.3)` dispara en `125/96r` | pitfall 4, con spec |
| 3 | `midi.md` | **los canales son 0–15**, no 1–16 | pitfall 7, con spec |
| 4 | `generative.md` | **Markov es él mismo una serie** y alimenta `play` directamente | `markov.rb:120` incluye `Serie::Base` |
| 5 | `neumas.md` | **el `NeumaDecoder` acumula estado** entre secciones | mismo decoder: `(+1)` → grado **5**; decoder nuevo: grado **1** |
| 6 | `midi.md` | **`MIDIVoices` no define `[]`**; se accede por `.voices[n]` | `method_defined?(:[])` → `false`, `(:voices)` → `true` |
| 7 | `transport.md` o la guía | **`transport.stop` no puede llamarse desde un trap handler**: alcanza `Mutex#synchronize` en el *reset* de *timing* del sequencer y lanza `ThreadError`; el transport **no para**. Poner una bandera en el trap y parar desde el hilo principal | reproducción completa en §0 |

**Y una limpieza que no depende de ninguna decisión**: borrar `Rules` de los seis
sitios del plugin donde sobrevive.

---

## 5bis. Ejecutado

Todo lo de la sección 5, más lo que salió al escribirlo. Suite: **963 ejemplos,
0 fallos**; doctest de `docs/`: **171 afirmaciones, 0 discrepancias, 0 errores**
(eran 162 — nueve claims nuevas, `DOCS_VERIFIED_FLOOR` subido).

**En musa-dsl:**

- `series.md` — corregido el bug de `RND` en la lista de constructores. **Y su
  ejemplo, que era una víctima colateral del mismo error**: con `.max_size(16)`
  sobre una `RND` que se agota daba 8 notas, y su `.remove` de repeticiones
  consecutivas era un no-op —en una permutación de valores distintos no puede
  haber repeticiones—. Ahora lleva `.repeat`, el orden correcto (`remove` antes
  de `max_size`, o el tope cuenta lo que el filtro va a tirar) y una declaración
  `# => 16` que lo sostiene.
- `series.md` — `.to_a` reinicia la instancia.
- `sequencer.md` — `at(1.3)` cae en `125/96r`.
- `midi.md` — canales 0–15; la voz se alcanza por `.voices`.
- `generative.md` — Markov es una serie, con lo que eso **no** implica; y **el
  valor de `finish:` se emite**, con su filtro.
- `neumas.md` — el decoder arrastra estado entre secciones, con `base=` como
  remedio.
- `transport.md` — `stop` desde un trap lanza `ThreadError` y no para nada.
- **`docs/guides/project-structure.md`**, nueva, con las diez prácticas del
  grupo B, enlazada desde el README. Fences `text`, por el precedente de
  `idioms.md`.

**En el plugin** (limpieza que no dependía de decisiones): `Rules` fuera de los
seis sitios; la guarda de Markov corregida; las dos afirmaciones falsas de
`philosophy.md` corregidas; los siete errores de sintaxis de
`state-machine-composition.md` arreglados.

**Pendiente de una acción de Javier**: `docs/guides/` está **sin trackear**, y el
gemspec arma la lista con `git ls-files` — hasta que se añada, la guía no viaja
en la gema.

### Un hallazgo del propio escribir

Escribiendo la guía usé `@markov.i.first(4)`. **Las series no tienen `.first`** —
`NoMethodError`. Lo caí porque lo ejecuté antes de darlo por bueno. Es el mismo
error que este pase persigue, cometido dentro del pase, y sólo el hábito de
verificar lo separó de quedar escrito en la documentación del framework.

## 6. Lo que falta

Del pase, nada: redactado y verificado, con la suite verde.

Lo que queda es **E1c propiamente**, que este pase deja preparado y no ejecuta:

1. `git add docs/guides/` en musa-dsl, o la guía no viaja en la gema.
2. **Borrar** `rules/musadsl-reference.md`, `rules/musadsl-philosophy.md`,
   `rules/best-practices.md` y `prompts/regenerate-*.md`, con los ajustes de
   `manifest.yml` y del generador que eso arrastra. Se han corregido *in situ*
   porque siguen embarcando hoy, no porque vayan a sobrevivir.
3. **Retirar del plugin las 17 prácticas** que mueren o migran (siete duplicadas,
   diez del grupo B ya escritas en la guía), dejando las cuatro del grupo C.
4. `tools/vocabulary.rb` + `docs/vocabulary.md` (PLAN-skills §5.9).

Verificación de lo hecho: **completa**. Ninguna afirmación quedó sostenida por
lectura de prosa.
