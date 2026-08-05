# Que las skills sean realmente útiles — estudio y plan

Estudio conjunto (Opus + Fable), agosto de 2026. **Nada de esto está
implementado**: el entregable es el análisis y el plan.

Contexto directo: `../plan-elegancia-idiomatica.md`, y en particular sus
secciones "Lo que F2.5 resultó ser", "El criterio de residencia", "F3, remedido
tras F2.6" y "Qué es teatro". Este documento sustituye y precisa lo que aquel
llamaba F3.

**Reformulado tras la objeción de Javier** (ver §0). La primera versión de este
plan daba por buena una premisa que no lo era, y a cambio de examinarla el plan
cambió de eje. La secuencia E0→E3 sobrevive; lo que cambia es *qué se consume* y
*qué trabajo hace la búsqueda*.

---

## 0. La objeción, y en qué acabó

Javier, sobre este plan:

> "buena parte del problema que intentamos resolver con la knowledge base es
> porque consideramos que cargar el contexto de información no es apropiado."

Es un eco de su corrección anterior, la que reorientó F2.5: *"has priorizado no
consumir contexto cuando precisamente disponer de contexto permite contrastar el
significado"*. Generaliza aquella corrección desde la auditoría documental hasta
la arquitectura del plugin.

### La medida

| kind | bytes | ≈ tokens | naturaleza |
|---|---:|---:|---|
| `api` | 5,16 MB | ~1,5 M | ilimitado |
| `private_works` | 1,05 MB | ~300 k | crece con cada obra |
| `demo_code` | 198 KB | ~57 k | crece |
| `docs` | 136 KB | ~39 k | **acotado: 13 subsistemas + idioms** |
| `analysis` | 134 KB | ~38 k | crece |
| `demo_readme` | 106 KB | ~30 k | acotado (22) |
| `gem_readme` | 47 KB | ~13 k | acotado |
| `best_practice` | 20 KB priv. + ~134 KB glob. | ~44 k | acotado |

Total ~2 M tokens: no cabe. Pero la **capa conceptual entera son ~90 k**, y
`docs` sola ~39 k. Cabe. Así que la objeción es material, no retórica.

### Lo que Opus propuso, y lo que no resistió

Opus propuso: el pecado de la KB no es recuperar sino recuperar *fragmentos*;
`get_doc` por nombre como pieza central; un índice conceptual siempre en
contexto; y `docs` dejando de ser kind buscable. Fable lo desmontó en tres
puntos, y los tres se aceptan:

1. **La analogía con F2.5 era falsa.** La patología de F2.5 era la
   **transcripción**: una copia que deriva de su original en silencio. Un chunk
   no es una transcripción — es el texto mismo, extraído mecánicamente y
   reconstruido en cada build. No puede derivar; como mucho llega **huérfano de
   contexto**. Son fallos distintos con remedios distintos, y fundirlos heredaba
   la autoridad moral de F2.5 sin ganársela.
2. **`get_doc` por nombre contradice la fila mejor fundamentada de este plan.**
   §4 dice que a `docs` le llega *"la forma del problema, **nunca** el nombre de
   la solución ya elegida"*. Pedir `get_doc("sequencer")` es abrir el libro por
   donde ya creías que estaba la respuesta: la skill que eligió mal leerá diez
   mil tokens de confirmación sin pasar jamás por la frontera, que vive en
   `series.md`. **No conserva el forzado epistémico: lo disuelve.**
3. **El índice siempre-en-contexto sí sería una capa de transcripción nueva** —
   mantenida a mano, derivando en silencio. Es exactamente donde ocurrió la
   amplificación de FIBO. Y peor: **la presencia no produce el acto**.
   `musadsl-philosophy.md` ya decía lo correcto y fue inerte durante cuatro
   commits; lo que cambió decisiones fue el artefacto obligatorio, no la
   información presente.

   *Javier decidió que sí lo haya* (decisión 5), aceptando la condición que el
   propio argumento imponía: **generado y verificado, jamás a mano**. Lo que
   sobrevive del reparo de Fable no es la prohibición sino el riesgo 12: el
   índice **alimenta** la puerta de modelado, no la sustituye. Diseño en §5.6.

Un cuarto: la correlación "los estratos acotados son los mal servidos" confundía
**acotado** con **minoritario**. F2.0 fue sesgo de proporciones (`docs` al 3,4 %
del corpus), no una penalización de lo acotado; y comparaba contra el estado
pre-E1, ya condenado por este mismo plan.

### El encuadre que queda

Ni "contexto contra MCP" ni "acotado contra ilimitado". **El eje es el tipo
epistémico de la consulta. El tamaño sólo decide la unidad de consumo.**

| tipo de consulta | primitivo | unidad de consumo | dónde |
|---|---|---|---|
| **nombre conocido** — identificador, rúbrica | lookup estructurado | la entrada, o el documento entero | `api` (`module`+`name`); `idioms.md` desde `analyze`; `get_doc` pedido por el usuario |
| **forma del problema** — no sé cómo se llama la respuesta | enrutado semántico sobre chunks → **lectura íntegra del documento ganador** | el documento | `docs` |
| **semejanza** — ¿existe algo parecido? | ranking por similitud | el chunk | `demo_readme`, `demo_code`, `private_works`, `analysis`, `best_practice` |

Esto clasifica bien lo que la dicotomía de Opus clasificaba mal: `demo_readme` es
acotado y su consulta es de semejanza pura, así que su primitivo son los
embeddings, no la carga en contexto.

Y responde a Javier sin bandos: **el contexto permanente es para los artefactos
que fuerzan actos** —pequeños, de ámbito de skill— **y la lectura íntegra ocurre
en el momento del juicio contrastivo, después de una consulta formulada por forma
del problema, no en su lugar.**

Lo concreto que Javier y Opus ganan contra el plan viejo: **la unidad de consumo
era miserable.** `format_results` trunca a 2000 caracteres (`db.rb:370`) y §1 ya
señalaba que la puerta de modelado se alimentaba de *"una consulta a un solo
fichero"*. Para sostener la columna "why not the neighbouring verb" hace falta el
documento con sus relaciones internas. Eso pide **leer entero lo encontrado**, no
dejar de buscar.

Corolario que ninguno de los dos había dicho: **la lectura-y-retención tiene un
fallo que la recuperación no tiene.** Tras compactación, la skill cree haber
leído lo que ya no está y nada se lo señala. Por eso la regla es *se relee al
disparar la puerta*, nunca *ya está cargado de antes*.

---

## 1. El diagnóstico

**Ninguna skill tiene escrito qué querría recibir.** La mala recuperación es la
capa visible de una relación mal contratada entre las skills y el conocimiento:
las skills usan la KB para **verificar** lo que ya eligieron, no para **decidir**.

- `code` paso 4: *"Research using MCP tools — **verify** everything"*.
- `analyze` paso 5: *"**Verify** MusaDSL API usage"*.
- `think` paso 9: la KB como aduana de fragmentos de código.

La capa que F2.2 escribió para **cuestionar** el marco —los "When is this the
answer", los 17 tramos de `idioms.md`— no tiene ni un solo paso, en ninguna
skill, cuyo trabajo sea preguntarle **antes** de formar el plan.

### El corolario

**Saber que hay que desconfiar del marco propio no basta.** `code` lo sabe, lo
escribe, y tiene su puerta de modelado con artefacto obligatorio (F1). Aun así
consulta mal, por **tres** motivos —el tercero es el que añade la reformulación:

1. su paso 4 lista siete herramientas describiendo **qué devuelven**, no **qué
   pregunta llevarles**;
2. la puerta que corrige el marco se alimenta de **una consulta a un solo
   fichero**;
3. y lo que recibe son **fragmentos truncados a 2000 caracteres**, que es la
   unidad equivocada para un juicio contrastivo: la frontera entre dos verbos
   vive en la relación interna del documento, no en el trozo que más se parece a
   la consulta.

### La segunda carencia, distinta de la primera

- **Qué se pregunta** — a qué capa, con qué formulación.
- **Qué se hace con lo recuperado** — cómo se relacionan las capas, qué pasa
  cuando discrepan.

De las cuatro que razonan, **sólo `explain` tiene un paso de síntesis**, y son
dos líneas sin papeles por capa. `think` y `analyze` pasan de "research" a
producir. Y como `format_results` borra el `kind`, ninguna podría razonar por
capas aunque quisiera: no sabe qué sostiene.

---

## 2. Bugs encontrados, verificados ejecutando

1. **Las 23 buenas prácticas globales están fuera del corpus público.**
   `chunker.rb:602` busca `nota-plugin/data/best-practices`; están en
   `src/data/best-practices` desde la reorganización del generador.
   `knowledge.db` tiene **0** trozos `best_practice`. Nada lo detectó porque
   **nada asevera que un kind esperado sea no vacío**.

2. **`similar_works` disfraza las obras del usuario de demos**
   (`search.rb:102`): `private_works` se funde en los tres huecos de la sección
   "Demo Descriptions" y se presenta bajo ese encabezado.

3. **`code` manda leer `docs/idioms.md` en local, y la guarda de fuentes del
   mismo fichero lo prohíbe** ("the user may not have them cloned"). El
   combustible de la puerta de modelado es inaccesible para quien no sea Javier.
   *(Muere por construcción con `get_doc`.)*

Menores: el enum de `SearchTool` omite `best_practice` en su texto aunque lo
acepta; `kind_counts` memoiza por `object_id`; `explain` recomienda literalmente
`kind "all" for broadest results`.

---

## 3. Lo que medimos

Diez preguntas escritas como las hace alguien componiendo — por intención, no por
API:

| búsqueda | capa conceptual entre los 5 primeros |
|---|---|
| `kind: "all"` | 3 de 10 |
| `kind: "docs"` | **10 de 10**, acertando la sección |

Las capas se separan **en bloque** por distancia relativa al primer resultado:
1,19–1,24× en preguntas sobre qué hacer, 1,43–1,81× en preguntas sobre una firma.
Es información **para la skill**, no política para el servidor.

`kind: "api"` no llena los 5 huecos en **10 de 13** consultas pese a ser el
56,8 % del corpus. No es sobre-búsqueda insuficiente: **KNN es el primitivo
equivocado para buscar un identificador.** Las columnas `module` y `name` están
pobladas en los 1341 trozos.

**Lectura reformulada del 10 de 10.** Ese resultado no dice que el chunk sea buen
alimento para decidir; dice que **el enrutado semántico acierta el documento y la
sección**. Es la evidencia que sostiene conservar `docs` como kind buscable, y es
lo único medido que puede llevar a la skill a un subsistema que *no* esperaba.
Con n=10 basta para matar `"all"`; **no basta para consagrar el enrutado**: E0
engorda la batería.

---

## 4. El fundamento: propiedad, capas y distribución

### 4.1 De quién es el conocimiento — la frontera musa-dsl / Nota

Principio de Javier: **musa-dsl es el dueño del conocimiento; Nota decide su
distribución.** Es §2 del catálogo (núcleo de dominio independiente, consumidores
como adaptadores), y su antipatrón describe el presente con exactitud
incómoda: *"cada uno con su propia copia parcial… los consumidores aprenden a
leer la realidad por su cuenta — divergiendo."*

**El criterio.** El del lector humano es buen test y mala definición. La
definición es:

> **El conocimiento en prosa reside donde puede ser falsado. Las
> representaciones derivadas mecánicamente residen donde se consumen, a condición
> de ser regenerables y verificadas.**

Una afirmación sobre musa-dsl sólo puede falsarla musa-dsl: sus specs,
`tools/doc-examples.rb`, su CI. Una copia dentro de Nota queda **fuera del alcance
de esa maquinaria**, y ahí es exactamente donde ocurrió FIBO: la fuente se
corrigió y la transcripción no sólo no se corrigió, sino que amplificó el error
con tipografía de énfasis. La residencia sigue a la verificación, no al lector.

El test del lector humano queda como **corolario para la prosa**: si algo sobre
musa-dsl merece decirse, merece decirse para humanos, en musa-dsl. **No existe la
categoría legítima "prosa sobre musa-dsl que sólo un LLM debe leer"** — esa
categoría *es* la definición operativa de lo que F2.5 demostró que deriva.

Y la frontera fina, que el criterio del lector no ve: un chunk, un embedding o un
índice extraído mecánicamente no sirven a ningún lector humano y aun así **no**
son de musa-dsl — son del pipeline que los consume, porque son extracción sin
juicio autoral, reconstruidos en cada build, incapaces de derivar en silencio.
Pero **en cuanto un artefacto derivado incorpora juicio autoral** —selección de
"lo importante", advertencias, condensación con criterio— **deja de ser derivación
y vuelve a ser prosa; y entonces su casa es musa-dsl, o la muerte.**

**El guardarraíl del sentido contrario.** La dirección es correcta y llevada lejos
viola §2 al revés: el núcleo cargando prosa cuyo único consumidor es un plugin.
El test, en una frase:

> **Un documento migra a musa-dsl sólo si, borrando Nota mañana, seguiría
> mereciendo existir.**

`idioms.md` lo pasa —Javier ya lo juzgó—. `api-reference.md` lo suspendió y Javier
lo borró. Lo suspenden taxativamente: **toda declaración de distribución** (un
front-matter `nota: always_load`, un manifiesto de qué cargar), la prosa dirigida
al LLM dentro de `docs/`, la coreografía de skills, los artefactos, los
frameworks y lo privado del usuario. Que musa-dsl dijera *"esto es lo que un
asistente debe cargar"* sería cruzar la línea aunque la frase fuera cierta.

El riesgo real no es un cruce puntual sino la **gravedad**: cada futuro "a Nota le
vendría bien X" tirará de prosa hacia la gema. Sin el test escrito con autoridad
—en `engineering-practices.md` como manifestación de §2— la frontera se erosiona
en tres peticiones razonables.

### 4.2 Las ocho capas con papel

El criterio de residencia de F2.5 extendido a la KB. **Debe vivir en un solo
sitio** (texto de la herramienta en el servidor) y ser citado por las skills; su
duplicación en cada una sería el vector de deriva.

| kind | papel | responde a | formulación | primitivo → consumo |
|---|---|---|---|---|
| `docs` (128) | el modelo mental | ¿cuándo es esto la respuesta? | la forma del problema, **nunca** el nombre de la solución ya elegida | enrutado semántico → **documento entero** |
| `api` (1341) | el contrato | ¿qué hace, con qué firma? | un identificador | lookup → la entrada |
| `demo_code` (626) | el cableado | ¿cómo se ve un caso montado? | técnica + contexto | semejanza → chunk |
| `demo_readme` (204) | el precedente público | ¿existe una pieza así? | la pieza imaginada | semejanza → chunk |
| `gem_readme` (60) | el ecosistema | ¿qué gema, qué instalación? | componente o setup | semejanza → chunk |
| `best_practice` (23 púb. + 38 priv.) | la convención | ¿cómo se hace esto *aquí*? | la técnica en uso | semejanza → chunk |
| `private_works` (3026) | la voz del usuario | ¿cómo lo resolví antes? | la propia práctica, descrita | semejanza → chunk |
| `analysis` (95) | el significado de esa voz | ¿qué tendencias tengo? | estética o trayectoria | semejanza → chunk |

**Tres reglas transversales:**

- **Un demo nunca justifica una elección de forma.** Responde "cómo se cablea",
  no "cuándo es la respuesta". Con el `kind` viajando en los resultados pasa de
  advertencia a regla operativa: *un resultado `[demo_code]` no puede sostener
  una fila de la tabla de modelado.*
- **Lo privado nunca se funde con lo público en un mismo ranking.**
- **Ninguna decisión de forma se sostiene sobre un snippet de `docs`.** El
  snippet enruta; el documento leído entero decide. La cita de la columna fuente
  se produce **con el texto presente**, no de memoria.

### 4.3 La regla de distribución — tres ejes que se componen

> **La propiedad decide la fuente** — musa-dsl para lo falsable allí, Nota para
> la conducta del asistente, el usuario para su voz (§4.1).
>
> **El tipo epistémico decide el mecanismo** — nombre conocido → lookup; forma
> del problema → enrutado semántico + lectura íntegra; semejanza → chunks (§0).
>
> **Y el momento decide la colocación: en contexto permanente vive únicamente lo
> que debe actuar *antes* de que exista una pregunta. Todo lo que puede esperar a
> una pregunta, se recupera.**

El tercer eje es el nuevo, y su justificación ya estaba latente: **no puedes
consultar por un reflejo que no sabes que tienes.** Por eso `idioms.md` —índice de
síntomas— va en contexto y `sequencer.md` no.

Corolarios que caen solos:

- Los artefactos de contexto permanente son **pocos y pequeños**.
- Los que son conocimiento de musa-dsl **se leen de la gema instalada en el
  arranque, jamás se copian**.
- Los que son conducta de Nota son suyos y estáticos (`think-journal.md`,
  `defaults/`).
- La regla anti-rancidez de §0 se extiende sin cambios: tras compactación, lo
  cargado al arranque está tan perdido como lo leído. **La puerta relee, no
  confía.**

Esto reclasifica los cuatro ficheros de `rules/` sin ambigüedad: dos eran
conocimiento de musa-dsl colocado en permanente **por copia** (`reference`,
`philosophy` → mueren), uno es mezcla (`best-practices` → se triaja), uno es
conducta (`think-journal` → se queda).

---

## 5. Qué pregunta cada skill

### 5.1 `code` — tiene la puerta; darle el combustible y la unidad correcta

| momento | capa | formulación | qué se extrae |
|---|---|---|---|
| **antes** de la tabla de modelado | `docs` (enrutar) | la forma del dato y del plan (*"a plan of sections each with a duration"*). Prohibido nombrar el verbo candidato | el documento que casa |
| inmediatamente después | `get_doc` del ganador | — | el modelo mental con sus relaciones internas |
| columna "why not the neighbouring verb" | del documento ya leído | el par concreto: *"cuándo es `every` y cuándo una serie"* | la frontera, citada |
| tras elegir idioma | `api` (lookup) | identificador exacto | firma + `@example` |
| al montar setup | `demo_code` | *"wiring TimerClock transport MIDIVoices"* | orden de montaje; **jamás** forma |
| al escribir material | `best_practice` | la técnica en uso | práctica, etiquetada por origen |
| sólo si toca obra del usuario | `private_works` + `analysis` | descripción musical | cómo lo resolvió antes |

**El artefacto ya existe** (la tabla de modelado): gana una columna **fuente**.
Cada fila cita `doc > section` **del documento leído entero**, no del snippet.
Una fila sin cita, o citando un `[demo_code]`, es visible en el transcript y
**falsable**.

**El índice de síntomas se promueve a artefacto global generado** (decisión 5b,
contra la recomendación de Fable y Opus; ver §5.6). No es una capa nueva: la
tabla Shape-to-Idiom (20 filas) y las Idiom Guards (10 guardas) de
`code/SKILL.md` ya son un índice de síntomas escrito a mano dentro de una skill.
Salen de ahí, se generan, se verifican y pasan a `src/rules/`.

### 5.2 `explain` — clasificar la pregunta antes de tocar nada

| la pregunta es… | capas, en orden |
|---|---|
| ¿cuándo uso X? ¿X o Y? | `docs` (enrutar) → `get_doc` entero → `api` |
| ¿qué hace X? ¿qué firma? | `api` → `docs` reformulada como la decisión detrás (explicar qué es algo sin decir cuándo es la respuesta es media explicación) |
| ¿cómo monto X? | `demo_code` (+ `gem_readme`) |
| ¿qué instalo? | `gem_readme` + `docs` |
| ¿algo de mi obra? | `analysis` / `private_works` |

Regla de síntesis: **`docs` lleva la voz, `api` verifica cada afirmación de
comportamiento, `demo` ilustra.** Prohibido responder el "cuándo" desde un demo.
Termina con un bloque de fuentes por capa.

### 5.3 `think` — menos consulta, no más

Es donde el reflejo de "consulta más" haría daño: convertiría una lista de ideas
en una lista de herramientas. `analysis` y `private_works` para el contexto del
usuario; `demo_readme` como precedente; `api` sólo como la guarda de verificación
que ya tiene. **`docs` no entra en la ideación temprana, deliberadamente, y eso
debe quedar escrito con su porqué** — si no, la próxima revisión lo "mejorará"
añadiéndolo. Con `get_doc` barato la tentación crece, así que el porqué se
refuerza en vez de relajarse. Excepción: preguntas de **viabilidad** (*"can one
serie be consumed at two paces"*), nunca de elección de herramienta.

### 5.4 `analyze` — de describir a juzgar

`docs` para la dimensión Idiomatic Usage, formulada como la forma que el código
exhibe: el análisis deja de decir "usa `every`" y pasa a decir "usa `every` donde
la capa conceptual dice serie".

**Única excepción legítima al lookup por nombre sobre `docs`**:
`get_doc("idioms")`. Ahí el documento no es una solución candidata sino **la
rúbrica** — la tarea es literalmente contrastar el código contra el catálogo, así
que el nombre no presupone nada. La regla general se enuncia así: *cuando la
consulta **es** un nombre, el lookup es honesto; cuando la consulta es un
problema, el nombre es autoengaño.*

Y antes de marcar `[consolidation candidate]`, consulta doble a `best_practice` y
`docs`: **si ya existe, o si es el idioma documentado del framework, no es una
práctica del usuario.**

### 5.5 Las utilitarias

`index`, `hello`, `setup`, `analysis-framework`, `inspiration-framework`: su
trabajo es CRUD/presentación, nombran la herramienta exacta y **no hacen búsqueda
semántica**. Ya es así; se escribe como criterio. No entran en este programa.

### 5.6 El índice conceptual — que es `idioms.md`, y ya existe

Decisión 5b de Javier, y luego su pregunta: *"E1b no es utilizar el idioms de
musa-dsl?"* Sí. Y la respuesta disuelve casi toda la fase que se había planeado.

**`idioms.md` son 12 KB, 332 líneas, ~3.500 tokens.** Cabe entero en el contexto
permanente sin discusión. Y no es materia prima que haya que destilar: **ya está
escrito como índice de síntomas**, con esta anatomía por entrada —

| campo | qué es |
|---|---|
| **Reflex** | el disparador por token: *"`a, b = b, a + b`, accumulators inside `loop`"* |
| **Idiom** | la respuesta del framework |
| **What is gained** | por qué |
| **Detectable** | *"the swap `a, b = b, a + b` is a literal grep"* |
| **When the reflex is right** | la salida honesta |

— y con un cierre, "Using this document", que **es la puerta de modelado**:
nombra la forma del dato, el verbo que la consume, y *why not the neighbouring
verb*. Las tres columnas de la tabla de modelado de `code`, en su fuente.

**De donde el hallazgo que reordena la fase: el plugin ya transcribe `idioms.md`
tres veces.**

| en `code/SKILL.md` | transcribe de `idioms.md` |
|---|---|
| tabla Shape-to-Idiom (20 filas) | los campos **Idiom** |
| Idiom Guards (10 guardas) | los campos **Reflex** y **Detectable** |
| las tres columnas de la tabla de modelado | la sección "Using this document" |
| el párrafo final sobre la clase a medida | "When the reflex is right" de #5, generalizado |

**Eso es la patología de F2.5, y no es un riesgo futuro: está en el árbol.** Nueve
de las diez Idiom Guards tienen su entrada correspondiente en `idioms.md` (`at` en
bucle → #1; el swap → #5; aritmética sobre notas MIDI → #3; `60.0/bpm` en el
material → #4; `rand` sin semilla → #6; `product`/`permutation` → #7; `every` que
empuja hacia un objetivo → #10; `sort_by` temporal → #11; constantes de posición
sumadas → #12). Y ahí es donde ocurrió la amplificación de FIBO: en la
condensación, no en la fuente.

**Así que no hay generador, no hay destilación y no hay tercer aserto.** El
artefacto es el documento. Lo que E1b hace es:

1. **Borrar las transcripciones** de `code/SKILL.md`: Shape-to-Idiom y las Idiom
   Guards. Reduce `code` en vez de engordarla — cobra el presupuesto del riesgo 1
   en lugar de gastarlo.
2. **Cargar `idioms.md` entero** desde la gema instalada, vía `get_doc`, al abrir
   sesión. 3.500 tokens, de la versión del usuario, sin copia intermedia.
3. **Un solo aserto en CI**, no tres: que el documento existe en la versión suelo
   y trae sus 17 entradas. La cobertura y la fidelidad dejan de necesitar
   verificación porque **no hay nada derivado que pueda divergir**.

**La décima guarda no se borra**: *"comprueba que el fichero tiene
`include Musa::Series`"* no es un idiom, es un fallo de setup que se oculta a sí
mismo. Va con las Critical Guards, que se quedan enteras — previenen código que
**falla**, no código ajeno al framework, y su fuente no es `idioms.md`.

**Lo que queda por decidir, y es de musa-dsl, no del plugin**: las 20 filas de
Shape-to-Idiom cubren cosas que `idioms.md` puede no tener entrada propia (p. ej.
*"el mismo material para varias voces" → `.buffered`*). Cada fila sin casa es una
de dos cosas: **una entrada que le falta a `idioms.md`** —y entonces se añade
allí, donde vive el catálogo— o algo genuinamente de nivel de skill. El repaso
fila a fila es parte de E1b; el destino de lo que sobre es de Javier.

**Pendiente relacionado**: `src/rules/musadsl-philosophy.md` (7,8 KB) es el
fichero que "decía lo correcto y fue inerte cuatro commits". Con `idioms.md`
entero en contexto hay que mirar si sigue aportando algo o es una cuarta
transcripción. No lo decide este plan.

**Lo que sigue vigente del reparo de Fable**: el documento presente no produce el
acto. `idioms.md` **alimenta** la puerta de modelado, no la sustituye. Si aparece
en contexto y las tablas de modelado siguen sin citas, fue decorativo, y §7.6 lo
hace visible.

### 5.7 El desalojo de `src/rules/` — Nota deja de tener conocimiento dentro

Aplicación de §4.1 a los 50,8 KB que el plugin lleva hoy siempre en contexto.

| fichero | bytes | veredicto |
|---|---:|---|
| `musadsl-reference.md` | 35.457 | **muere**, tras pase de salvamento |
| `musadsl-philosophy.md` | 7.812 | **muere**, tras pase de salvamento |
| `best-practices.md` | 4.480 | **muere** con la redistribución de sus fuentes |
| `think-journal.md` | 3.099 | **se queda** — es conducta de Nota |
| `src/defaults/` (análisis, inspiración) | — | **se quedan** — definen qué mira el asistente, no son falsables contra musa-dsl |

**`musadsl-reference.md` es el antipatrón de §2 en estado puro**: 35 KB de
transcripción manual del API, regenerados por un LLM leyendo fuentes. El prompt
`prompts/regenerate-reference.md` es el vector de FIBO institucionalizado. Se
sustituye por tres piezas, **ninguna escrita a mano**:

1. `idioms.md` en contexto (E1b) — cubre *cómo se piensa aquí*.
2. `api_reference` estructurado + `get_doc` (E1) — cubren firma y comportamiento
   bajo demanda.
3. **El vocabulario**, que es lo único que la reference daba y que nada del plan
   reponía: **saber qué existe**. Los nombres (`S`, `H`, `HC`, `MERGE`,
   `play_timed`, `move`, `Variatio`…) sin los cuales no se puede ni formular un
   lookup. Lo publica musa-dsl; ver §5.9.

**`musadsl-philosophy.md`** dice de sí mismo que *"answers **why** each
abstraction exists and **when** it is the right choice"*. Eso es literalmente lo
que F2.2 escribió como "When is this the answer" en los 13 subsistemas. Es la
cuarta copia.

**Pase de salvamento, obligatorio antes de borrar.** Los 35 KB contienen material
verificado contra fuente que puede no estar en ningún otro sitio (pitfalls,
órdenes de montaje). El procedimiento es el mismo que §5.6 define para
Shape-to-Idiom: fila a fila, y **cada afirmación sin casa es una adición a
musa-dsl o muere justificadamente**. Ejemplo de Fable: el encuadre *"generative
tools operate upstream of series"* — si `generative.md` no lo dice con esa
claridad, es una entrada que le falta a musa-dsl, no una razón para conservar la
copia.

**Las 23 buenas prácticas no son una cosa, son tres**, y el triaje es fichero a
fichero:

| grupo | qué es | ejemplos | destino |
|---|---|---|---|
| **A** | hechos del framework disfrazados de práctica | `decoder-state-reset`, `timer-clock-start` (que `transport.start` bloquea), `ctrl-c-thread-safe` (el Mutex del stop), `refinements-per-file`, `rational-timing` | **a la documentación de musa-dsl**, y mueren como "práctica". Que el Mutex del transport esté documentado sólo en un plugin es indefendible |
| **B** | el oficio de componer con musa-dsl | `separation-main-score`, `module-thescore-pattern`, `shutdown-pattern`, `voice-accessor`, `state-machine-composition` | **a musa-dsl como guía de convenciones** — *guides* frente a *reference*: la convención de proyecto de Rails es doctrina de Rails, no de un plugin. Sirve al lector humano: es lo primero que pregunta un recién llegado |
| **C** | la voz del usuario | lo que se justifica por cómo compone Javier, no por cómo es musa-dsl | **no migra**: ya tiene mecanismo (privadas en `~/.config/nota/`, kind `best_practice`, semejanza) |

Prueba operativa para arbitrar: **¿la justificación cita una propiedad de
musa-dsl o una preferencia del compositor?** La banda media existe y sólo Javier
la arbitra.

### 5.8 El contrato con la gema — la forma mínima

Si Nota "le pregunta a la gema", ¿qué le pregunta? La respuesta honesta es: **casi
nada nuevo.**

1. **`get_doc(name)`** — ya diseñado (E1). Suficiente para el consumo.
2. **`list_docs`** — enumerar `gem_dir/docs/` con el primer encabezado de cada
   fichero. **El sistema de ficheros ya es el manifiesto**: `docs/` tiene
   estructura con significado. Es derivación mecánica, no exige que musa-dsl
   publique nada, y evita que las skills lleven una lista de documentos cableada
   —que sería la capa de punteros del riesgo 9 en versión estática.
3. **Nada más.** Una declaración de "qué conviene cargar siempre" queda prohibida
   por §4.1. Que Nota dependa del nombre `idioms.md` es dependencia normal de
   consumidor sobre interfaz publicada: **la flecha apunta en la dirección
   correcta**. El coste es fragilidad ante reorganizaciones de `docs/`, y se paga
   con lo ya decidido — el chequeo de apertura de sesión afirma el contrato
   entero contra la versión suelo. *Consumidor que se ancla, núcleo que no se
   entera*: eso es §2.

**Descartado** (decisión 13): un `docs/README.md` que explique el mapa. Se borró
en esta sesión por redundante y sus rutas subieron al README principal; no se
replica. `list_docs` **enumera y no interpreta**: listar un directorio y tomar el
primer encabezado de cada fichero es acceso a disco, no conocimiento del dominio.
Decidir cuáles importan sí lo sería.

### 5.9 `docs/vocabulary.md` — lo publica musa-dsl, y es un lint suyo

Decisión 11 de Javier: **lo publica musa-dsl, porque Nota no tiene por qué saber
cómo obtenerlo.** Si Nota sabe *extraer* el índice, Nota vuelve a llevar dentro
conocimiento sobre la estructura de musa-dsl — §4.1 otra vez, en versión sutil.

Eso obliga a responder qué es ese fichero **para musa-dsl**, y la respuesta lo
salva del guardarraíl en vez de rozarlo: **no es un índice para Nota, es el
vocabulario del framework** — qué nombres públicos enseña la documentación
conceptual, por subsistema. Un *cheat sheet*. Borrando Nota mañana, seguiría
mereciendo existir: todos los frameworks tienen uno.

**Cómo se genera, sin juicio autoral nuevo**: cruzando dos fuentes **ya
verificadas** —

- el **API público** de `lib/`: el mismo conjunto que `.yardopts --no-private`
  publica en rubydoc;
- los **identificadores nombrados por los 13 `docs/subsystems/`**, cuyo contenido
  ya ejecuta `tools/doc-examples.rb`.

La **intersección** es el vocabulario: *lo que la documentación conceptual
considera digno de nombrar*. Y las dos **diferencias** caen gratis, y son un lint
que musa-dsl debería tener de todos modos:

| diferencia | qué significa |
|---|---|
| nombrado en `docs/`, ausente del API público | **la documentación se inventó API** — exactamente el hallazgo de esta sesión: *"core-extensions.md: most of the API was invented"* |
| público, no nombrado por ningún subsistema | **hueco de documentación** |

De donde la herramienta no es un generador para el plugin: es
**`tools/vocabulary.rb`, un lint que mantiene en correspondencia la documentación
conceptual y el API público, y que imprime esa correspondencia como documento.**
El índice es su subproducto visible.

**Forma**: fichero commiteado `docs/vocabulary.md`, regenerado por la herramienta,
con **aserto de frescura en la suite** —igual que los ratchets ya existentes—. El
gemspec lo publica solo, GitHub lo muestra, y el diff se ve cuando el vocabulario
cambia, que ya es información. Nota lo carga en el arranque como carga
`idioms.md`: leyéndolo de la gema instalada, sin copia.

**Si el vocabulario sale pobre, se corrige en los `docs/` de musa-dsl, nunca en el
extractor.** La presión de calidad empuja hacia la fuente.

**Consecuencia (decisión 11 de Javier): `prompts/regenerate-*.md` desaparecen los
dos** — `regenerate-reference.md` (8,4 KB) y `regenerate-philosophy.md` (5,8 KB).
Su existencia era el síntoma: un prompt que pide a un LLM releer las fuentes y
reescribir una copia es **la transcripción convertida en proceso**.

**Mecanismo de inyección, verificado**: los dos harnesses pueden cargar contexto
resuelto en el arranque, por caminos distintos. Claude Code tiene el hook
`session_start` (hoy `ensure_db.rb`). opencode declara `hooks_json: false`, **pero
su wrapper TS empuja rutas de fichero a `cfg.instructions` desde una función
`config` que corre al arrancar** — puede apuntar directamente al `docs/idioms.md`
de la gema instalada. La condición en ambos: **resolver la ruta en tiempo de
sesión, no de build**, porque la versión instalada del usuario cambia.

---

## 6. Qué cambia en el MCP

- **`search` muere `"all"`.** Pasa a aceptar una lista de `{kind, query}`, cada
  una embebida y buscada **por separado**, cada una bajo su encabezado, **sin
  mezclar rankings**. `kind` obligatorio, sin `"all"` en el enum, sin default: el
  uso incorrecto se vuelve **imposible**, no desaconsejado.
- **El formato lleva el kind y la distancia** de cada resultado, con la nota de
  que las distancias sólo son comparables dentro de una misma consulta. Distingue
  "sin resultados en rango útil" de "colección vacía".
- **`search` con `kind: "docs"` declara su papel**: cada resultado lleva su
  snippet **y su dirección de documento**, con el mandato —en el texto de la
  herramienta, no duplicado en las skills— de que *el snippet enruta y no decide*.
- **`api_reference` pasa a lookup estructurado** sobre `module`+`name`, con
  fallback semántico **etiquetado** y un **"Not found in the indexed API"**
  inequívoco. Hoy nunca dice que no, así que la escalera KB→rubydoc→GitHub que
  las skills tienen escrita nunca se sube.
- **`pattern` y `dependencies` se eliminan.** Sin alias transitorios: un alias es
  una decisión aplazada que nadie vuelve a tomar.
- **`similar_works` se parte, no sólo se etiqueta** (decisión 4). Misma forma que
  `search`: **rankings separados por colección**, cada uno bajo su encabezado,
  etiquetados pública / privada. No basta con rotular un ranking mezclado —
  la preeminencia de una colección eclipsaría a la otra por similitud, que es el
  mismo fallo que mató a `"all"` un nivel más abajo.
- **`get_doc(name)` — de última entrada a pieza temprana.** E2 depende de ella, y
  es el consumo correcto para el juicio contrastivo. **Lee de la gema
  instalada**: `Gem::Specification.find_by_name('musa-dsl').gem_dir`, porque el
  gemspec incluye `docs/` (`git ls-files` menos `test|spec|features|samples`), y
  así el documento es **el de la versión que el usuario tiene**. La respuesta
  **declara siempre qué versión sirvió**.

  Arregla un desajuste que la variante indexada no toca: hoy `knowledge.db` se
  construye desde el árbol de fuentes del momento del build, así que quien tenga
  0.43.1 recibe la documentación de 0.49.0. Es el mismo problema que este
  programa persigue, un nivel más arriba, y resuelto por construcción.

  **Suelo de versión duro, sin repliegue** (decisión 6). Por debajo del suelo,
  `get_doc` no sirve un documento degradado: falla y manda actualizar. Medido:

  | versión | subsistemas con "When is this the answer" |
  |---|---|
  | 0.43.1, 0.47.1 | 0 / 13 |
  | 0.47.3 | 13 / 13 |
  | 0.48.0, 0.49.0 | 13 / 13 |

  **Pero el suelo no es 0.47.3, es 0.49.0.** Entre 0.47.3 y 0.49.0 los `docs/`
  cambiaron 639 líneas insertadas y 506 borradas en 16 ficheros —330 sólo en
  `sequencer.md`, el subsistema más consultado— porque ahí es donde F2.5 corrigió
  las ~45 afirmaciones falsas. Un 0.47.3 tiene la sección **y tiene el contenido
  que este programa demostró falso**. El suelo honesto no es *"tiene la capa
  conceptual"* sino ***"tiene la capa conceptual ejecutada y verificada"***.

  **Y se comprueba al abrir sesión, no al disparar la puerta.** `ensure_db.rb` ya
  corre al arrancar; ahí se resuelve la versión instalada y se avisa. Fallar a
  mitad de una composición es peor que negarse en la puerta, y convierte un
  requisito en un accidente. Consecuencia asumida: **el plugin declara `musa-dsl
  >= 0.49.0` como requisito explícito** en el README y en el manifiesto. Deja de
  funcionar con gemas antiguas, a propósito.

  **No sustituye a la búsqueda**: `get_doc` da recuperación exacta de un
  documento nombrado y no puede enrutar. Son complementarias, y ése es justo el
  punto: enruta `search`, consume `get_doc`.
- **Reversión de la cuota conceptual** (`db.rb:233-250, 322-347`).
  **`KNN_OVERSHOOT` y `kind_counts` SOBREVIVEN**: son la corrección de F2.0, y
  con `kind` obligatorio dejan de ser una pelea para ser diez líneas de
  correctitud. Tirarlos resucitaría el bug justo cuando las skills empezarían a
  confiar en pedir la capa conceptual.

---

## 7. Cómo se sabrá que ha funcionado

Los cuatro teatros documentados comparten anatomía: instrucción sin artefacto ni
instrumento. Cada pieza lleva el suyo.

1. **Batería de recuperación** en `tools/`, ampliada a medir **enrutado**: cada
   pregunta por forma-del-problema con su blanco esperado (`doc > section` en el
   top-k de `docs`). Enrutar es ahora el único trabajo de la búsqueda sobre
   `docs`, así que es lo que hay que medir. **Baseline antes de tocar nada** — el
   plan viejo perdió el "antes" de F1 y lo lamenta. Y **n=10 no basta**: E0 la
   engorda.
2. **Citas falsables como artefacto**: la columna fuente de `code`, el bloque de
   fuentes de `explain`, el contraste citado de `analyze`. Un `doc > section`
   existe o no; un script trivial lo verifica.
3. **Verificación de punteros y del índice conceptual**: las direcciones
   `doc > section` son **una capa derivada**, y las capas derivadas se verifican
   o mienten. Los tres asertos de §5.6 —cobertura, direcciones, anclaje de la
   destilación— corren en CI contra los `docs/` de la versión suelo.
4. **Imposibilidad interfacial**: sin `"all"`, sin default, con `api_reference`
   capaz de decir que no.
5. **El protocolo de F5.1** (los encargos, que sólo Javier puede escribir): qué
   llamadas con qué `{kind, query}` hizo la skill, y si el idioma elegido es el
   esperado. La batería mide que la capa llega; los encargos miden que **cambia
   la decisión**. Es además lo único que puede saldar la apuesta central del
   encuadre nuevo: **nadie ha medido si leer el documento entero cambia la
   decisión frente al chunk de 2000 caracteres.**
6. **Síntoma observable del propio fracaso**: si tras E2 la tabla de modelado
   aparece sin citas, o citando demos, el fallo está en el transcript de
   cualquier sesión.

---

## 8. Riesgos

**Del encuadre viejo, vigentes:**

1. **Dilución por longitud.** `code` ya son 185 líneas de mandatos compitiendo.
   Si las coreografías se **añaden** en vez de **sustituir**, el modelo saturará
   y elegirá qué obedecer. Presupuesto: `code` no crece netamente.
2. **La formulación sigue saliendo del marco propio.** Obligar a preguntar por
   capas no garantiza preguntar bien. Riesgo residual real; lo mide F5.1.
3. **Las citas degeneran en liturgia.** La falsabilidad lo convierte en riesgo
   detectable, que es lo máximo que se puede pedir.
4. **Revertir de más** (ver `KNN_OVERSHOOT`).
5. **Fracaso por orden**: desplegar E2 sin E0 dejaría las skills nuevas
   consultando una capa medio vacía sin forma de verlo.
6. **Deriva de mantenimiento**: cada skill retocada puede reintroducir un `"all"`
   conceptual. La tabla §4 en un solo sitio es la defensa.

**Nuevos, propios del encuadre nuevo:**

7. **Confirmación por nombre.** Todo camino que permita llegar a un documento sin
   pasar por la formulación del problema reabre el agujero que §4 cierra.
   Mitigación: el mandato vive en el texto de las herramientas, y la columna
   fuente exige que la cita venga del documento que **el enrutado** señaló —
   salvo la excepción-rúbrica de `analyze`.
8. **Creencia rancia post-compactación**: "ya leí `series.md`" cuando ya no está.
   Regla: se relee al disparar la puerta.
9. **La batería no cubre lo que el usuario lee.** E3 verifica contra
   `knowledge.db`; `get_doc` sirve la gema instalada, que puede ser otra versión.
   El desfase que la variante-gema cierra por un lado lo abre por el otro
   (puntero de skill → sección renombrada en la versión del usuario). De ahí el
   chequeo de punteros y la declaración de versión en cada respuesta.
10. **Coste de atención real**: ~10 k tokens por cruce de puerta; tres puertas en
    una sesión son ~30 k de docs. No es fatal, pero es exactamente el "razonar
    sobre el pajar" que el propio análisis señaló. Sin F5.1 nadie sabrá si la
    lectura íntegra cambia decisiones o sólo las encarece.
**De las decisiones tomadas, asumidos a sabiendas:**

11. **El suelo excluye usuarios** (decisión 6). Quien tenga musa-dsl < 0.49.0 no
    obtiene capa conceptual: el plugin se lo dice al abrir sesión y no le sirve
    documentación degradada. Es un requisito, no un accidente, y por eso va en el
    README y en el manifiesto. Desaparece a cambio el riesgo del repliegue mal
    hecho — no hay repliegue.
12. **`idioms.md` en contexto puede ser decorativo** (decisión 5). Es el reparo
    que Fable esgrimía y que la decisión asume: la presencia no produce el acto,
    y `musadsl-philosophy.md` fue inerte cuatro commits estando presente y siendo
    correcto. **Alimenta la puerta, no la sustituye.** Síntoma observable: si está
    en contexto y las tablas de modelado siguen sin citas, fue decorativo (§7.6).

*Desaparecen los riesgos de destilación y de distorsión que llevaba la versión
generada del índice: sin capa derivada no hay nada que pueda divergir. Y con la
retirada de Shape-to-Idiom y las Guards, el riesgo 1 (dilución de `code`) se
cobra en vez de gastarse.*

**Del desalojo de `rules/` (§5.7):**

13. **Arranque en frío — la única regresión real del programa.** Al morir los
    35 KB de reference, lo que queda al arranque es `idioms.md` (~3,5 k) más el
    índice de superficie (~2–4 KB). El formato de neumas y el orden de montaje
    tienen casa en musa-dsl (`neumas.md`, `docs/examples/`): un `get_doc` de
    distancia. El índice de demos ya lo sirve `demo_readme` por semejanza.
    **La pérdida real es otra: la conversación *fuera* de las skills pierde la
    red.** MusaDSL es una gema de nicho y el preentrenamiento apenas la conoce,
    así que sin red toda afirmación de API no consultada es candidata a
    alucinación. El índice de superficie mata la alucinación de **nombres** —la
    más dañina—; las de **comportamiento** sólo las fuerza a herramienta la
    disciplina de citas de E2, que **no cubre la charla libre**. Es una regresión
    acotada; hay que nombrarla, no negarla, y sólo F5.1 dirá si es tolerable.
14. **Acoplamiento por contrato.** Cada reorganización de `docs/` en musa-dsl pasa
    a ser una release coordinada con Nota (suelo + asertos), sin un repositorio
    umbrella que lo medie. Es el precio estructural del principio de §4.1 y es un
    precio correcto — pero conviene decirlo: **musa-dsl gana un consumidor con
    expectativas contractuales sobre nombres de fichero**, no sólo sobre API.
15. **La gravedad hacia el núcleo.** Riesgo dominante a largo plazo: sin el test
    *"si Nota desapareciera"* escrito en un sitio con autoridad, la gema
    acumulará prosa con forma de consumidor a razón de una petición razonable por
    vez.

---

## 9. Orden

```
E0  instrumentos y suelo   batería AMPLIADA (enrutado + n mayor) y baseline;
                           fix de chunker.rb:602; aserción de kinds no vacíos;
                           rebuild
E1  MCP                    reversión de la cuota (KNN_OVERSHOOT sobrevive);
                           search multi-consulta, lista de {kind, query},
                           kind obligatorio, rankings sin mezclar;
                           formato con kind/distancia/recuento;
                           get_doc desde la gema instalada, suelo 0.49.0
                           comprobado al abrir sesión, sin repliegue;
                           api_reference estructurado;
                           similar_works partido por colección;
                           eliminación de pattern y dependencies
E1b idioms.md entero       borrar Shape-to-Idiom y las Idiom Guards de
                           code/SKILL.md; cargar idioms.md de la gema instalada
                           al abrir sesión; un aserto (existe, 17 entradas);
                           repaso fila a fila de lo que no tenga casa
E1c desalojo de rules/     [musa-dsl] tools/vocabulary.rb + docs/vocabulary.md
                           + aserto de frescura; pase de salvamento de
                           reference.md y philosophy.md; triaje A/B/C de las 23
                           prácticas
                           [nota]     carga de vocabulary.md desde la gema;
                           borrado de los tres rules/ y de prompts/regenerate-*
E2  interior de las skills code, explain, analyze, think — por sustitución.
                           Enrutar → leer entero → citar.
                           Tabla §4.2 en un único lugar; las skills dejan de
                           citar los ficheros muertos
E3  medición               batería en CI + asertos del contrato documental +
                           protocolo F5.1
```

La secuencia no cambia. Lo que cambia dentro: `get_doc` sube a E1 temprano porque
E2 depende de ella; la batería de E0 crece porque ahora mide enrutado; **E1b es
hija de la decisión 5b**; y **E1c es hija del principio de propiedad de §4.1**.

E1b va antes que E1c a propósito: es un caso pequeño y ya decidido del mismo
patrón —leer de la gema en el arranque— y **prueba el mecanismo que E1c
generaliza**. E1c tiene además una particularidad de gobierno: **su mitad A/B vive
en el repositorio de musa-dsl, no en el del plugin**, y al entrar allí mueve el
suelo de versión (ver decisión 9).

E1 gana dos cosas por §5.8: **`list_docs`**, y un chequeo de sesión endurecido —
no gatea sólo `get_doc` sino **la capa conceptual entera**, porque sin gema
`search kind:"docs"` enrutaría hacia documentos que `get_doc` no puede servir, y
**un router sin destino es un estado roto a medias, peor que la negativa
franca**.

Fuera y para después, conscientemente: F3.5 (mapa de decisión generativa) y el
sucesor curado de `pattern`.

---

## 10. Decisiones — tomadas

Todas resueltas por Javier el 4 de agosto de 2026. Ninguna queda pendiente.

1. **Forma de `search`** → **lista de `{kind, query}` en una llamada**, cada una
   embebida y rankeada por separado. El esquema mismo enseña que consultar es
   formular varias preguntas distintas, y omitir una capa queda visible en la
   firma.
2. **¿Quién sirve el documento entero?** → **`get_doc` como acto separado**.
   `search` enruta y devuelve punteros. La deliberación —enruté aquí, y por eso
   leo esto— debe verse en el transcript; incrustada sería invisible.
3. **`pattern` y `dependencies`** → **eliminadas**, sin alias transitorios.
4. **`similar_works`** → **etiquetada Y partida**: rankings separados por
   colección, no un ranking mezclado con rótulos. Razón de Javier, y es la misma
   que mató a `"all"` un nivel más abajo: *que la preeminencia de unos no eclipse
   a los otros*.
5. **¿Artefacto conceptual siempre en contexto?** → **sí**, contra la
   recomendación de Fable y Opus. Y la pregunta que Javier hizo después —*"¿E1b
   no es utilizar el idioms de musa-dsl?"*— resultó ser la respuesta: **el
   artefacto es `idioms.md` entero**, 3.500 tokens, ya escrito como índice de
   síntomas. No hay generador, ni destilación, ni asertos de anclaje, porque no
   hay capa derivada. Y al mirarlo se vio que **el plugin ya lo transcribía tres
   veces** dentro de `code/SKILL.md`. Diseño en §5.6.
6. **Política de versión de `get_doc`** → **fallar y mandar actualizar**. Sin
   repliegue a documento degradado. Consecuencias derivadas y asumidas (§6): el
   suelo es **0.49.0**, no 0.47.3 —0.47.3 tiene las secciones pero con el
   contenido que F2.5 demostró falso, 639 líneas después—, se comprueba **al
   abrir sesión** en vez de al disparar la puerta, y el plugin pasa a declarar
   `musa-dsl >= 0.49.0` como requisito explícito.

**Cerrada durante la reformulación:**

7. **¿Sigue `docs` siendo kind buscable?** Opus proponía que no; Fable argumentó
   que el enrutado semántico es el único mecanismo **medido** que corrige el
   marco (10 de 10, acertando la sección) y el único que puede dejar a la skill
   en un subsistema que no esperaba. **Opus concede: sí, como router.**

---

## 10bis. Decisiones del principio de propiedad (§4.1) — tomadas

Resueltas por Javier el 4 de agosto de 2026.

8. **¿Acepta musa-dsl el papel de guía opinionada de estructura de proyecto?**
   (las prácticas del grupo B) → **sí**. Queda por resolver, dentro del trabajo:
   buena parte no es ejecutable por `doc-examples.rb` (MIDI, hilos, traps), así
   que necesitará *fences* `text` como `idioms.md` o una exención declarada.
9. **Política de suelo móvil** → **sí, el suelo sube** cuando el contenido
   redistribuido entre en musa-dsl (0.50.x). Coherente con la decisión 6, y con
   el coste asumido: cada subida vuelve a excluir usuarios.
10. **Caso "sin gema instalada"** → **requisito duro**, dicho en la puerta. Ni
    repliegue a los docs de `knowledge.db` (sería el desfase que `get_doc` existe
    para cerrar) ni copia vendorizada. La pieza tampoco puede **sonar** sin la
    gema; el mensaje de sesión da el comando exacto.
11. **El vocabulario** → **lo publica musa-dsl**, porque Nota no tiene por qué
    saber cómo obtenerlo. Diseño en §5.9: lint de correspondencia entre el API
    público y la documentación conceptual, con el índice como subproducto.
    **Consecuencia derivada por Javier: mueren los `prompts/regenerate-*.md`.**
13. **`docs/README.md`** → **no**. Se borró por redundante en esta sesión y no se
    replica. `list_docs` enumera sin interpretar.

**Y el reparto del trabajo (12), acordado:**

| quién | qué |
|---|---|
| **Opus** | el pase completo de `musadsl-reference.md` (35 KB) y `musadsl-philosophy.md` (7,8 KB) afirmación por afirmación: localizar cada una en los `docs/` de musa-dsl (**está** → muere como duplicado; **no está** → candidata, con texto propuesto y fichero destino). Clasificar las 23 prácticas en A/B/C con la evidencia de cada una. Entregar una hoja: afirmación → veredicto → evidencia → destino |
| **Javier** | (1) **la banda media del triaje**, donde la justificación es ambigua entre propiedad del framework y preferencia del compositor — es su práctica; (2) **aprobar lo que entra en musa-dsl**, porque el texto que pasa a ser documentación del framework es autoría; (3) **los conflictos**: si una afirmación de `reference.md` contradice los `docs/`, es un issue a investigar, no una edición — la misma regla que con sus specs |

---

## 11. Estado

**E0, E1, E1b, E1c y E2: hechas.** Queda E3.

### E0

- `chunker.rb`: **aserción de kinds no vacíos**, probada forzándola. El bug de la
  ruta de buenas prácticas queda además cerrado por construcción.
- `db.rb`: **`prune_absent`** — el índice dejaba dentro para siempre lo que
  desaparecía de las fuentes. Once trozos de `api-reference.md` y `docs/README.md`,
  borrados de musa-dsl a propósito, seguían respondiendo preguntas.
- `knowledge.db` reconstruida y podada: **2390 trozos, exactamente los del
  corpus**. `docs` 128→142, `best_practice` 0→16, cero `Rules`.
- **`tools/retrieval-battery.rb`**: 32 preguntas por intención, con blanco
  `documento > sección`. Baseline en `tools/retrieval-baseline.json`.
  **23/32 al primer resultado, 29/32 en el top 3, 32/32 en el top 5.**

### E1

Muere `"all"` —cero apariciones en el servidor—; `search` acepta una lista de
`{kind, query}` rankeadas por separado; los resultados llevan kind y distancia, y
distinguen «nada en rango» de «colección vacía»; `api_reference` busca por nombre
y **sabe decir que no**; `similar_works` parte por colección; fuera `pattern` y
`dependencies`; **`get_doc` y `list_docs`** leen de la gema instalada; la cuota
conceptual revertida con `KNN_OVERSHOOT` intacto; y la tabla de las ocho capas
vive en **un solo sitio**, el texto de las herramientas.

La batería no se mueve del baseline, que es el resultado correcto: la cuota sólo
actuaba sobre `"all"`, y ninguna consulta legítima usaba `"all"`.

### E2

`code`: consultar es una pregunta por capa; la puerta enruta con `docs`, lee el
documento entero con `get_doc` y la tabla de modelado gana **columna fuente**.
`explain`: clasifica la pregunta antes de tocar nada, `docs` lleva la voz, `api`
verifica, `demo` ilustra, y termina en un bloque de fuentes. `analyze`: juzga en
vez de describir, con `get_doc("idioms")` como rúbrica, y doble comprobación antes
de marcar `[consolidation candidate]`. `think`: **consulta menos**, con la
exclusión de `docs` en la ideación temprana escrita y razonada.

`code` **encoge un 9 %** (16 007 → 14 519 bytes) al sustituir Shape-to-Idiom y las
Idiom Guards por el `idioms.md` que ya viaja en contexto.

### Pendiente

- **E3a**, para 1.0: batería en CI y verificación de las citas
  `documento > sección` que las skills producen.
- **E3b — aplazada a Nota 2.0**: el protocolo de encargos (F5.1). Decisión de
  Javier, agosto de 2026.

  Se aplaza el instrumento, no lo que dice. Sigue siendo cierto que la batería
  mide que la capa llega y **sólo los encargos miden que cambia la decisión**, y
  que **nadie ha medido si leer el documento entero decide mejor que un fragmento
  de 2000 caracteres** — la apuesta central del encuadre de §0, que 1.0 embarca
  sin saldar. Escribirlo mal sería peor que no tenerlo: el estándar es la forma
  de escribir de Javier, y una batería que yo redactara mediría mi consistencia
  conmigo mismo. Hasta 2.0, lo que hay contra la regresión es la batería de
  recuperación y la falsabilidad de las citas.
- `nota-plugin` **sin bump ni push**.

Ver `SALVAMENTO.md` para el pase que precedió a E1c.

En musa-dsl (suite 963/0, doctest 171 afirmaciones/0 discrepancias):

- `tools/vocabulary.rb` + `docs/vocabulary.md` + `spec/vocabulary_spec.rb`
- `docs/guides/project-structure.md` con las diez prácticas del grupo B
- siete adiciones a los subsistemas y un bug de `series.md` corregido

En nota-plugin:

- `mcp_server/musa_docs.rb` — lee `idioms.md` y `vocabulary.md` de la **gema
  instalada**, **sin suelo de versión**: presencia por fichero, y la versión declarada en cada respuesta; `--paths` para opencode,
  `session_start.rb` para Claude Code
- `rules/` reducido a `think-journal.md`; fuera `musadsl-reference.md`,
  `musadsl-philosophy.md`, `best-practices.md` y `prompts/` entero
- 19 de las 23 prácticas retiradas; quedan las cuatro del grupo C
- `chunker.rb:602` **arreglado** (era E0): `best_practice` pasa de 0 a 16 trozos,
  y ahora avisa cuando una fuente no rinde nada

**Contexto permanente: de 47,7 KB copiados a 17 KB leídos de la gema.**

### Pendiente

- **musa-dsl 0.49.1 conviene publicarla antes que el plugin**, para que el
  vocabulario exista. No bloquea nada: cualquier gema con `docs/idioms.md`
  —desde 0.47.1— sirve, y se dice qué falta.
- **E0 salvo el fix ya hecho**: batería de recuperación con su baseline, aserción
  de kinds no vacíos, y rebuild de `knowledge.db` (necesita `VOYAGE_API_KEY`).
- **E1**: la cirugía del MCP — muere `"all"`, `search` multi-consulta,
  `api_reference` como lookup, `similar_works` partida, fuera `pattern` y
  `dependencies`, `get_doc` y `list_docs` sobre `MusaDocs.path_of`, reversión de
  la cuota conceptual (commit `25764a8`, con `KNN_OVERSHOOT` sobreviviendo).
- **E2** y **E3** intactas.
- `nota-plugin` **sin bump ni push**, según lo acordado.
