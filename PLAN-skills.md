# Que las skills sean realmente útiles — estudio y plan

Estudio conjunto (Opus + Fable), agosto de 2026. **Nada de esto está
implementado**: el entregable es el análisis y el plan.

Contexto directo: `../plan-elegancia-idiomatica.md`, y en particular sus
secciones "Lo que F2.5 resultó ser", "El criterio de residencia", "F3, remedido
tras F2.6" y "Qué es teatro". Este documento sustituye y precisa lo que aquel
llamaba F3.

---

## 1. El diagnóstico

**Ninguna skill tiene escrito qué querría recibir.** La mala recuperación es la
capa visible de una relación mal contratada entre las skills y el conocimiento:
las skills usan la KB para **verificar** lo que ya eligieron, no para **decidir**.

- `code` paso 4: *"Research using MCP tools — **verify** everything"*.
- `analyze` paso 5: *"**Verify** MusaDSL API usage"*.
- `think` paso 9: la KB como aduana de fragmentos de código.

La capa que F2.2 escribió para **cuestionar** el marco —los "When is this the
answer", los 17 tramos de `idioms.md`, todos indexados como `docs`— no tiene ni
un solo paso, en ninguna skill, cuyo trabajo sea preguntarle **antes** de formar
el plan.

### El corolario que no habíamos dicho

**Saber que hay que desconfiar del marco propio no basta.** `code` lo sabe y lo
escribe:

> These tools verify what you already chose: `api_reference` confirms the
> signature of a method you had in mind, `search` returns what matches your
> framing. If your framing is wrong, they will confirm the wrong thing. The step
> that corrects the framing is step 5, not this one.

Y tiene su puerta de modelado con artefacto obligatorio (F1). Aun así consulta
mal, por dos motivos: su paso 4 lista siete herramientas describiendo **qué
devuelven**, no **qué pregunta llevarles**; y la puerta que corrige el marco se
alimenta de **una consulta a un solo fichero**.

### La segunda carencia, distinta de la primera

Conviene no fundirlas:

- **Qué se pregunta** — a qué capa, con qué formulación.
- **Qué se hace con lo recuperado** — cómo se relacionan las capas, qué pasa
  cuando discrepan.

Una skill puede arreglarse en la primera y seguir siendo inútil por la segunda.
De las cuatro que razonan, **sólo `explain` tiene un paso de síntesis**, y son
dos líneas ("combine retrieved context with the static reference") sin papeles
por capa. `think` y `analyze` pasan de "research" a producir: el paso intermedio
no existe como instrucción. Y como `format_results` borra el `kind`, ninguna
podría razonar por capas aunque quisiera: no sabe qué sostiene.

---

## 2. Bugs encontrados, verificados ejecutando

1. **Las 23 buenas prácticas globales están fuera del corpus público.**
   `chunker.rb:602` busca `nota-plugin/data/best-practices`; están en
   `src/data/best-practices` desde la reorganización del generador.
   `knowledge.db` tiene **0** trozos `best_practice`. La instrucción de `code` de
   buscar `kind: "best_practice"` sólo encuentra las privadas del usuario.
   Nada lo detectó porque **nada asevera que un kind esperado sea no vacío**.

2. **`similar_works` disfraza las obras del usuario de demos**
   (`search.rb:102`): `private_works` se funde en los tres huecos de la sección
   "Demo Descriptions" y se presenta bajo ese encabezado.

3. **`code` paso 5 manda leer `docs/idioms.md` en local, y la guarda de fuentes
   del mismo fichero lo prohíbe** ("the user may not have them cloned"). El
   combustible de la puerta de modelado es inaccesible para cualquier usuario
   que no sea Javier.

Menores: el texto del enum de `SearchTool` omite `best_practice` aunque el enum
lo acepta; `kind_counts` memoiza por `object_id`; `explain` recomienda
literalmente `kind "all" for broadest results`.

---

## 3. Lo que medimos

Diez preguntas escritas como las hace alguien componiendo — por intención, no
por API:

| búsqueda | capa conceptual entre los 5 primeros |
|---|---|
| `kind: "all"` | 3 de 10 |
| `kind: "docs"` | **10 de 10**, acertando la sección |

Y las capas se separan **en bloque** por distancia relativa al primer resultado:
1,19–1,24× en preguntas sobre qué hacer, 1,43–1,81× en preguntas sobre una
firma. Es información **para la skill**, no política para el servidor.

`kind: "api"` no llena los 5 huecos en **10 de 13** consultas pese a ser el
56,8 % del corpus. **Encuadre corregido**: no es sobre-búsqueda insuficiente, es
que KNN es el primitivo equivocado para buscar un identificador. Las columnas
`module` y `name` están pobladas en los 1341 trozos de API.

---

## 4. El fundamento: las ocho capas con papel

El criterio de residencia de F2.5 extendido a la KB. **Debe vivir en un solo
sitio** (texto de la herramienta en el servidor) y ser citado por las skills; su
duplicación en cada una sería el vector de deriva.

| kind | papel | responde a | formulación que le llega |
|---|---|---|---|
| `docs` (128) | el modelo mental | ¿cuándo es esto la respuesta? decisión, frontera, sorpresa | la forma del problema/dato, **nunca** el nombre de la solución ya elegida |
| `api` (1341) | el contrato | ¿qué hace exactamente, con qué firma? | un identificador — lookup, no similitud |
| `demo_code` (626) | el cableado | ¿cómo se ve un caso montado? | técnica + contexto de montaje |
| `demo_readme` (204) | el precedente público | ¿existe una pieza así? | la pieza imaginada, descrita |
| `gem_readme` (60) | el ecosistema | ¿qué gema, qué instalación? | componente o necesidad de setup |
| `best_practice` (23 públicas + 38 privadas) | la convención | ¿cómo se hace esto *aquí*? | la técnica en uso |
| `private_works` (3026) | la voz del usuario | ¿cómo lo resolví antes? | la propia práctica, descrita musicalmente |
| `analysis` (95) | el significado de esa voz | ¿qué tendencias tengo? | estética o trayectoria |

**Dos reglas transversales:**

- **Un demo nunca justifica una elección de forma.** Responde "cómo se cablea",
  no "cuándo es la respuesta". Con el `kind` viajando en los resultados esto pasa
  de advertencia en prosa a regla operativa: *un resultado `[demo_code]` no puede
  sostener una fila de la tabla de modelado.*
- **Lo privado nunca se funde con lo público en un mismo ranking.**

---

## 5. Qué pregunta cada skill

### 5.1 `code` — tiene la puerta; darle el combustible

| momento | capa | formulación | qué se extrae |
|---|---|---|---|
| **antes** de la tabla de modelado | `docs` | la forma del dato y del plan (*"a plan of sections each with a duration"*). Prohibido nombrar el verbo candidato | la sección que casa → alimenta las filas |
| columna "why not the neighbouring verb" | `docs` | el par concreto: *"when is `every` the answer and when is a serie"* | la frontera, citada |
| tras elegir idioma | `api` (lookup) | identificador exacto | firma + `@example` |
| al montar setup | `demo_code` | *"wiring TimerClock transport MIDIVoices"* | orden de montaje; **jamás** forma |
| al escribir material | `best_practice` | la técnica en uso | práctica, etiquetada por origen |
| sólo si toca obra del usuario | `private_works` + `analysis` | descripción musical | cómo lo resolvió antes |

**El artefacto ya existe** (la tabla de modelado): gana una columna **fuente**.
Cada fila cita `source > section` del trozo `docs` que sostiene el verbo. Una
fila sin cita, o citando un `[demo_code]`, es visible en el transcript y
**falsable**.

### 5.2 `explain` — clasificar la pregunta antes de tocar nada

| la pregunta es… | capas, en orden |
|---|---|
| ¿cuándo uso X? ¿X o Y? | `docs` → `api` |
| ¿qué hace X? ¿qué firma? | `api` → `docs` (reformulada como la decisión detrás: explicar qué es algo sin decir cuándo es la respuesta es media explicación) |
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
añadiéndolo. Excepción: preguntas de **viabilidad** (*"can one serie be consumed
at two paces"*), nunca de elección de herramienta.

### 5.4 `analyze` — de describir a juzgar

`docs` para la dimensión Idiomatic Usage, formulada como la forma que el código
exhibe: el análisis deja de decir "usa `every`" y pasa a decir "usa `every` donde
la capa conceptual dice serie". Y antes de marcar `[consolidation candidate]`,
consulta doble a `best_practice` y `docs`: **si ya existe, o si es el idioma
documentado del framework, no es una práctica del usuario.** Hoy nada impide que
el circuito llene la biblioteca privada de "prácticas" que son el framework bien
usado.

### 5.5 Las utilitarias

`index`, `hello`, `setup`, `analysis-framework`, `inspiration-framework`: su
trabajo es CRUD/presentación, nombran la herramienta exacta y **no hacen búsqueda
semántica**. Ya es así; se escribe como criterio. No entran en este programa.

---

## 6. Qué cambia en el MCP

- **`search` muere `"all"`.** Pasa a aceptar una lista de `{kind, query}`, cada
  una embebida y buscada **por separado**, cada una bajo su encabezado, **sin
  mezclar rankings**. `kind` obligatorio, sin `"all"` en el enum, sin default: el
  uso incorrecto se vuelve **imposible**, no desaconsejado.
- **El formato lleva el kind y la distancia** de cada resultado, con la nota de
  que las distancias sólo son comparables dentro de una misma consulta. Distingue
  "sin resultados en rango útil" de "colección vacía" — hoy indistinguibles, y la
  colección vacía existe.
- **`api_reference` pasa a lookup estructurado** sobre `module`+`name`, con
  fallback semántico **etiquetado** y un **"Not found in the indexed API"**
  inequívoco. Hoy nunca dice que no, así que la escalera KB→rubydoc→GitHub que
  las skills tienen escrita nunca se sube.
- **`pattern` y `dependencies` se retiran**: sus cuotas fijas y formulaciones
  embebidas son el servidor haciendo el trabajo de la skill.
- **`similar_works` sobrevive** con secciones etiquetadas por colección y sin
  fundir lo privado en los huecos de los demos.
- **Nueva `get_doc(source)`**: todos los trozos de un documento en orden. Resuelve
  lo de `idioms.md`. Barata, sin embeddings.

  **Variante mejor, de Javier: leerlo de la GEMA INSTALADA, no del índice.** La
  gema publica sus `docs/` (16 ficheros; el gemspec los incluye a propósito),
  así que `Gem::Specification.find_by_name('musa-dsl').gem_dir` da el documento
  íntegro y **de la versión que el usuario tiene**.

  Eso arregla un desajuste de versión que la variante indexada no toca: hoy
  `knowledge.db` se construye desde el árbol de fuentes que hubiera en el
  momento del build, así que quien tenga 0.43.1 instalado recibe de la KB la
  documentación de 0.48.0. Es el mismo problema que este programa lleva
  persiguiendo, un nivel más arriba, y por construcción en vez de por
  disciplina.

  Dos límites: **no sustituye a la KB** — la búsqueda semántica necesita los
  embeddings precalculados, y esto da recuperación exacta de un documento
  nombrado; son complementarias. Y hay que decidir el repliegue cuando no haya
  gema instalada.
- **Reversión de la cuota conceptual** (`db.rb:233-250, 322-347`).
  **`KNN_OVERSHOOT` y `kind_counts` SOBREVIVEN**: son la corrección de F2.0, y
  tirarlos resucitaría el bug justo cuando las skills empezarían a confiar en
  pedir la capa conceptual.

---

## 7. Cómo se sabrá que ha funcionado

Los cuatro teatros documentados comparten anatomía: instrucción sin artefacto ni
instrumento. Cada pieza lleva el suyo.

1. **Batería de recuperación** en `tools/`: las preguntas medidas, cada una con
   su blanco esperado (`source > section` en el top-k de su kind). Se corre
   contra cada KB construida. **Baseline antes de tocar nada** — el plan viejo
   perdió el "antes" de F1 y lo lamenta.
2. **Citas falsables como artefacto**: la columna fuente de `code`, el bloque de
   fuentes de `explain`, el contraste citado de `analyze`. Una cita
   `source > section` existe en la KB o no; un script trivial la verifica.
3. **Imposibilidad interfacial**: sin `"all"`, sin default, con `api_reference`
   capaz de decir que no.
4. **El protocolo de F5.1** (los encargos, que sólo Javier puede escribir): qué
   llamadas con qué `{kind, query}` hizo la skill, y si el idioma elegido es el
   esperado. La batería mide que la capa llega; los encargos miden que **cambia
   la decisión**.
5. **Síntoma observable del propio fracaso**: si tras E2 la tabla de modelado
   aparece sin citas, o citando demos, el fallo está en el transcript de
   cualquier sesión.

---

## 8. Riesgos

1. **Dilución por longitud.** `code` ya son 185 líneas de mandatos compitiendo.
   Si las coreografías se **añaden** en vez de **sustituir**, el modelo saturará
   y elegirá qué obedecer. Presupuesto: `code` no crece netamente.
2. **La formulación sigue saliendo del marco propio.** Obligar a preguntar por
   capas no garantiza preguntar bien. Riesgo residual real; lo mide F5.1, no lo
   elimina nadie.
3. **Las citas degeneran en liturgia.** La falsabilidad lo convierte en riesgo
   detectable, que es lo máximo que se puede pedir.
4. **Revertir de más** (ver `KNN_OVERSHOOT` arriba).
5. **Ruido en contexto**: 5 resultados × 4 capas × 2000 chars. Mitigación:
   `n_results` por entrada (2-3 para contratos, 3-5 para docs).
6. **Fracaso por orden**: desplegar E2 sin E0 dejaría las skills nuevas
   consultando una capa medio vacía sin forma de verlo — el patrón "sirvió el
   error con más confianza" que F2.6 existía para evitar.
7. **Deriva de mantenimiento**: cada skill retocada puede reintroducir un `"all"`
   conceptual ("busca ampliamente"). La tabla §4 en un solo sitio es la defensa.

---

## 9. Orden

```
E0  instrumentos y suelo   batería + baseline; fix de chunker.rb:602;
                           aserción de kinds no vacíos; rebuild
E1  MCP                    reversión de la cuota (KNN_OVERSHOOT sobrevive);
                           search multi-consulta con kind obligatorio;
                           formato con kind/distancia/recuento;
                           api_reference estructurado; similar_works etiquetado;
                           retirada de pattern y dependencies; get_doc
E2  interior de las skills code, explain, analyze, think — por sustitución,
                           con citas falsables; tabla §4 en un único lugar
E3  medición               batería en CI + protocolo F5.1
```

Fuera y para después, conscientemente: F3.5 (mapa de decisión generativa) y el
sucesor curado de `pattern`.

---

## 10. Decisiones pendientes de Javier

1. **La forma de `search`**: lista de `{kind, query}` en una llamada, o un kind
   por llamada. La lista tiene una virtud más allá de la latencia — **el esquema
   enseña que consultar es formular varias preguntas distintas**, y omitir una
   capa queda visible — pero complica el esquema.
2. **`pattern` y `dependencies`**: retirar, o dejar alias transitorios.
3. **`similar_works`** es la única excepción defendible a "muere `all`":
   comparar obras sin importar quién las escribió es legítimamente transversal.
   Propuesta: secciones etiquetadas. Conviene decidirlo, no arrastrarlo.

---

## 11. Estado al pausar

- **Nada implementado de este plan.**
- La cuota conceptual **sigue en el árbol** (commit `25764a8`), pendiente de
  revertirse en E1.
- `knowledge.db` reconstruida sobre el corpus corregido y verificada: ninguna de
  las afirmaciones falsas de musa-dsl sobrevive en el índice.
- `nota-plugin` **sin bump ni push**, según lo acordado hasta cerrar las fases.
