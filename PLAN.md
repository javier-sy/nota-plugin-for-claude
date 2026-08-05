# Lo que queda, y qué mirar mientras tanto

Documento único de lo pendiente, escrito al cerrar Nota 1.0.0 el 5 de agosto de
2026. Sustituye a `plan-elegancia-idiomatica.md`, `PLAN-skills.md` y
`SALVAMENTO.md`, que quedaron obsoletos al ejecutarse.

**Se lee después de componer unas cuantas obras, no antes.** Lo que queda no está
bloqueado por trabajo: está bloqueado por no saber todavía si hace falta.

---

## 1. Lo que no hay que volver a discutir

Cuatro cosas se decidieron con su porqué. Reabrirlas sin evidencia nueva es
rehacer el camino.

**La forma del dato decide el idioma.** El reflejo generalista no se comete al
escribir el bucle sino al elegir la forma del plan. Con posiciones absolutas el
bucle de `at` ya es inevitable y ninguna guarda posterior salva. De ahí la puerta
de modelado, que vive en el único momento en que el error aún es barato.

**musa-dsl es el dueño del conocimiento; Nota decide su distribución.** El
conocimiento en prosa vive donde puede ser falsado: la gema tiene suite, doctest
que ejecuta cada afirmación de su documentación, y CI. Toda copia dentro del
plugin quedaba fuera de las tres, y todas derivaron. Guardarraíl del otro lado,
para que la gema no cargue prosa cuyo único lector sea un plugin: **un documento
migra a musa-dsl sólo si, borrando Nota mañana, seguiría mereciendo existir.**

**Toda afirmación sobre comportamiento se verifica ejecutando, no leyendo.** Cada
capa se genera desde la anterior, y una falsedad no sólo sobrevive al viaje: se
amplifica, porque condensar es opinar y al opinar sobre una falsedad se la
convierte en norma. Ocurrió con `FIBO`. Y volvió a ocurrir dentro de la propia
sesión que lo corregía, dos veces.

**Lo que no se puede olvidar se automatiza; lo que exige criterio se argumenta.**
Un lint para las formas regexables, una tabla escrita para las decisiones. Nunca
al revés.

---

## 2. Lo que 1.0 no sabe de sí mismo

**Nadie ha medido si leer el documento entero decide mejor que leer un
fragmento.** El sistema se reconstruyó sobre esa idea, está argumentada, y cuesta
unos 10 k tokens cada vez que se cruza la puerta de modelado.

La batería mide que el documento correcto es **alcanzable**. Que cambie lo que se
escribe es otra cosa, y sólo se ve componiendo.

Es la apuesta central del rediseño y sale sin saldar. Todo lo de la sección 4
existe para saldarla.

---

## 3. Qué mirar mientras compones

Esto es el trabajo real de esta fase. No hay que escribir nada todavía: hay que
**anotar cuándo el plugin acierta y cuándo estorba**. Seis síntomas, cada uno
ligado a algo que quedó pendiente o sin medir.

1. **¿Lees la tabla de modelado, o la saltas?** Si la saltas, la puerta es
   ceremonia y hay que rediseñarla, no reforzarla.
2. **¿Las citas `documento > sección` de la tabla dicen algo, o son decorado?**
   Una cita que nunca has comprobado es una liturgia con tipografía.
3. **Cuando el lint señala algo del apartado "worth arguing", ¿la justificación
   que da es buena?** Si es siempre la misma frase, el lint enseñó a producir
   excusas en vez de a pensar. Es su modo de fallo, y es el argumento para F4.2 o
   contra ella.
4. **¿Echas de menos leer el documento entero, o te sobra?** Si las decisiones
   salen igual de bien con el fragmento, la lectura íntegra es un gasto elegante
   y hay que quitarla.
5. **¿Aparece algún recurso de MusaDSL que no habías pedido y que encajaba?** Es
   el criterio de éxito del programa entero, textualmente: *"ofrece al menos un
   recurso del framework que el usuario no había pedido y que encaja"*.
6. **¿Cuánto tarda una práctica tuya en volver a ti?** Si `analyze` detecta un
   patrón y sólo lo aprovechas la obra siguiente, eso es F5.2.

Anótalo en el momento, no de memoria. Una nota de una línea por obra vale más que
un recuerdo de tres.

---

## 4. Lo pendiente

### F5.1 — la batería de encargos · **Nota 2.0**

Ocho a doce encargos compositivos con **solución idiomática conocida, escrita por
ti**: el encargo en términos musicales, tu solución, y por qué esa es la forma
—qué filas tendría su tabla de modelado—. Se le pasan a la asistencia y se
comparan **por forma, no por resultado sonoro**.

Sólo puedes escribirla tú: el estándar es tu manera de escribir, y una batería
redactada por la asistencia mediría su consistencia consigo misma. Debe incluir
**al menos un caso donde el reflejo generalista sea correcto** —una clase a medida
justificada—, o mide obediencia en vez de juicio.

Se corrige mirando cuatro cosas: qué `{kind, query}` pidió, si leyó el documento
entero, si la tabla tiene citas y de qué capa, y el idioma elegido contra el tuyo.
Lo interesante son las discrepancias parciales.

**Empieza por dos, no por doce.** Si el protocolo no te dice nada con dos, está
mal calibrado.

Es lo único que salda la sección 2, y lo único que detecta regresiones de juicio
cuando el plugin cambie.

### F4.2 — el pase de idioma · *depende del síntoma 3*

Releer el diff completo tras escribir y presentar las divergencias **como opciones
con precio** —qué cuesta cambiarlo, qué se gana—, no como correcciones. Separado
del pase de corrección, porque mezclarlos estropea los dos: o las divergencias se
arreglan por reflejo y se pierden las decisiones legítimas, o los errores de
verdad se descuentan.

Su aportación propia frente al lint es ver **la forma del conjunto** —tres clases
donde el framework tiene una abstracción, un plan modelado como posiciones de
principio a fin— que ninguna línea suelta delata.

Versión más afilada que la del plan original: releer el diff contra **la tabla de
modelado que se llenó**, no contra el catálogo en abstracto. La pregunta es
*¿construiste lo que dijiste que ibas a construir?*, y una tabla se puede rellenar
con optimismo.

Si se hace, **como segunda mitad del paso del lint**, no como paso nuevo: `code`
ya son mandatos compitiendo por atención.

### F5.2 — la latencia del circuito · *depende del síntoma 6*

`analyze` → `best-practices` produjo la práctica correcta una vez, con retraso de
una obra entera. Que se dispare por propuesta y no por obra.

Es optimizar algo que ya funciona. Sólo vale la pena si el síntoma 6 aparece.

---

## 5. Los instrumentos que hay

```
make check                      servidor + contrato documental + specs
make battery                    32 preguntas por intención, falla si empeora
make contract                   los documentos que Nota lee siguen donde dice
bundle exec rspec               13 invariantes
```

En CI, `build-release` corre el contrato y la batería antes de publicar una
`knowledge.db`, y el troceador aborta si un kind esperado sale vacío.

En musa-dsl: `bundle exec rspec` (964 ejemplos), `tools/doc-examples.rb` (171
afirmaciones de la prosa, 0 discrepancias) y `tools/vocabulary.rb`, que además de
generar el vocabulario reporta lo que la documentación nombra y no existe.

**Qué hacer si la batería falla**: mirar si el corpus se movió legítimamente o si
algo se rompió. Sólo en el primer caso se toma un baseline nuevo, y eso deja un
diff.

---

## 6. Una tarea de higiene

`plan-elegancia-idiomatica.md` vivía en `MusaDSL/`, que no es un repositorio, y
era el documento con más razonamiento acumulado del programa. Este documento
recoge lo que de él sigue vigente; el resto era historia de un trabajo ya hecho.

Los otros dos —`PLAN-skills.md` y `SALVAMENTO.md`— sí estaban versionados aquí,
así que su texto completo sigue en la historia de este repositorio si alguna vez
hace falta volver a por el razonamiento entero.

Lección para la próxima: **un plan que gobierna trabajo versionado debe estar
versionado con él.**
